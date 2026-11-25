part of 'reactive_library.dart';

/// Controls admission of overlapping asynchronous reactive computations.
enum LxAsyncConcurrency {
  /// Launch every invalidation and publish only the latest execution result.
  latest,

  /// Run at most one computation and coalesce changes into one trailing run.
  exhaustLatest,
}

/// A value derived from other reactive objects.
///
/// [LxComputed] automatically tracks its dependencies and re-evaluates
/// when they change. Calculations are lazy and memoized. Dynamic tracking
/// verifies each read before reusing an unchanged dependency order; conditional
/// or reordered reads still update subscriptions automatically.
///
/// // Example usage:
/// ```dart
/// final firstName = 'John'.lx;
/// final lastName = 'Doe'.lx;
///
/// // Updates only when firstName or lastName changes
/// final fullName = LxComputed(() => '${firstName()} ${lastName()}');
/// ```
class LxComputed<T> extends _ComputedBase<T> {
  final T Function() _compute;
  final bool Function(T previous, T current)? _equals;
  bool _isDirty = true;
  bool _isComputing = false;
  bool _hasComputeError = false;
  bool _pendingEagerRecompute = false;
  bool _hasPendingValueNotification = false;
  // Prevent duplicate reactive updates when dirty-state was already emitted.
  bool _notifiedDirty = false;

  final bool _staticDeps;
  final bool _eager;
  bool _hasStaticGraph = false;
  bool _initialHasCollectionReads = false;
  List<int>? _capturedDepVersions;

  // Captures first-run dependencies during constructor initialization.
  static final List<_DependencyTracker> _initialDepStack = [];

  /// Creates a synchronous computed value.
  ///
  /// The [compute] function is called to calculate the value.
  /// Use [staticDeps] to optimize performance if the dependency graph never changes.
  /// Use [equals] to define custom equality logic.
  LxComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
    bool staticDeps = false,
    bool eager = false,
    String? name,
  }) : _equals = equals,
       _staticDeps = staticDeps,
       _eager = eager,
       super(_computeInitial(name, _compute), name: name, equals: equals) {
    _isDirty = true;
    // Initial dependencies are reused on first activation to avoid a second run.
    if (_initialDepStack.isNotEmpty) {
      final tracker = _initialDepStack.removeLast();
      _initialHasCollectionReads = tracker.hasCollectionReads;
      final deps = tracker.dependencies.toList(growable: false);
      _capturedDeps = deps;
      _capturedDepVersions = List<int>.generate(
        deps.length,
        (i) => deps[i]._version,
        growable: false,
      );
      _capturedReactives = tracker.trackReactives
          ? tracker.reactives.toList()
          : null;

      if (_staticDeps) {
        _hasStaticGraph = true;
      }

      if (_capturedReactives != null) {
        maybeNotifyGraphChange(_capturedReactives!);
      }

      // Constructor already produced a value; subscriptions are attached on activation.
      _isDirty = false;
      _releaseTracker(tracker);
    }
  }

  static T _computeInitial<T>(String? name, T Function() compute) {
    // Capture first dependency graph during initial compute.
    final tracker = _getTracker();
    tracker.trackReactives = LevitReactiveMiddleware._hasGraphChangeMiddlewares;

    final previousProxy = _LevitReactiveCore.proxy;
    _LevitReactiveCore.proxy = tracker;

    try {
      final value = compute();
      _initialDepStack.add(tracker);
      return value;
    } catch (_) {
      _releaseTracker(tracker);
      rethrow;
    } finally {
      _LevitReactiveCore.proxy = previousProxy;
    }
  }

  /// Creates an asynchronous computed value.
  ///
  /// The [compute] function must return a [Future].
  ///
  /// Set [showWaiting] to `true` to emit [LxWaiting] when recomputing.
  /// Set [staticDeps] to `true` if the dependency graph is constant.
  static LxAsyncComputed<T> async<T>(
    Future<T> Function() compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    bool staticDeps = false,
    T? initial,
    String? name,
    LxAsyncConcurrency concurrency = LxAsyncConcurrency.latest,
  }) {
    return LxAsyncComputed<T>(
      compute,
      equals: equals,
      showWaiting: showWaiting,
      staticDeps: staticDeps,
      initial: initial,
      name: name,
      concurrency: concurrency,
    );
  }

  /// Creates a deferred computation that runs in a microtask and returns [LxStatus].
  ///
  /// This is useful when you want to convert a synchronous calculation into
  /// a status-wrapped asynchronous flow without explicitly using async/await.
  /// Creates a deferred computation that runs in a microtask and returns [LxStatus].
  ///
  /// This is useful when you want to convert a synchronous calculation into
  /// a status-wrapped asynchronous flow without explicitly using async/await.
  static LxAsyncComputed<T> deferred<T>(
    T Function() compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    bool staticDeps = false,
    T? initial,
    String? name,
    LxAsyncConcurrency concurrency = LxAsyncConcurrency.latest,
  }) {
    return LxAsyncComputed<T>(
      () async => compute(),
      equals: equals,
      showWaiting: showWaiting,
      staticDeps: staticDeps,
      initial: initial,
      name: name,
      concurrency: concurrency,
    );
  }

  @override
  void _onActive() {
    _isActive = true;
    if (_capturedDeps != null) {
      final deps = _capturedDeps!;
      final versions = _capturedDepVersions;
      var stale = false;
      for (var i = 0; i < deps.length; i++) {
        final dep = deps[i];
        if (dep.isDisposed ||
            (versions != null && dep._version != versions[i])) {
          stale = true;
          break;
        }
      }
      // Apply constructor-captured graph on first activation only when all
      // captured dependencies remain alive and unmodified.
      if (stale ||
          (_initialHasCollectionReads && deps.any((dep) => dep.isDisposed))) {
        _hasStaticGraph = false;
        _isDirty = true;
      } else {
        _reconcileDependencies(deps, reactives: _capturedReactives);
      }
      _capturedDeps = null;
      _capturedDepVersions = null;
      _capturedReactives = null;
    }

    if (_isDirty) {
      _cleanupSubscriptions();
      _recompute();
    }
  }

  @override
  void _onInactive() {
    _isActive = false;
    _hasStaticGraph = false;
    _isDirty = true;
    _pendingEagerRecompute = false;
    _hasPendingValueNotification = false;
    _cleanupSubscriptions();
  }

  @override
  void _propagateNotify() {
    if (_pendingEagerRecompute) {
      _pendingEagerRecompute = false;
      final hadPending = _hasPendingValueNotification;
      if (!_isClosed && _isActive && _isDirty) {
        _recompute();
      }
      if (hadPending &&
          _hasPendingValueNotification &&
          !_isPendingPropagate &&
          !_isPendingSyncBatch) {
        _hasPendingValueNotification = false;
        super._propagateNotify();
      }
      return;
    }
    _hasPendingValueNotification = false;
    super._propagateNotify();
  }

  @override
  void _publishMutation() {
    if (_LevitReactiveCore._isPropagating ||
        _LevitReactiveCore._batchDepth > 0) {
      _hasPendingValueNotification = true;
    }
    super._publishMutation();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || !_isActive) return;
    if ((!_isDirty || _hasComputeError) && !_isComputing) {
      // Stream listeners require eager recompute to push latest value.
      if (_hasStreamListener || _eager) {
        _isDirty = true;
        if (_LevitReactiveCore._isPropagating ||
            _LevitReactiveCore._batchDepth > 0) {
          _pendingEagerRecompute = true;
          _notifyListenersOnly();
        } else {
          _recompute();
        }
        return;
      }

      // Plain listeners observe dirty state and pull on next read.
      _isDirty = true;
      _notifiedDirty = true;
      // Emit reactive update without forcing immediate recomputation.
      _notifyListenersOnly();
    }
  }

  // Reusable tracker pool to reduce allocation pressure.
  static _DependencyTracker? _spareTracker;
  static final List<_DependencyTracker> _trackerPool = [];

  static _DependencyTracker _getTracker() {
    final spare = _spareTracker;
    if (spare != null) {
      _spareTracker = null;
      return spare;
    }
    if (_trackerPool.isEmpty) {
      return _DependencyTracker();
    }
    return _trackerPool.removeLast();
  }

  static void _releaseTracker(_DependencyTracker tracker) {
    tracker.clear();
    if (_spareTracker == null) {
      _spareTracker = tracker;
    } else {
      _trackerPool.add(tracker);
    }
  }

  void _recompute() {
    if (_isClosed || !_isActive || _isComputing) return;
    _isComputing = true;
    _pendingEagerRecompute = false;

    // Static dependency mode skips graph tracking after first successful capture.
    if (_staticDeps && _hasStaticGraph) {
      T resultValue;
      try {
        resultValue = _compute();
      } catch (_) {
        _hasComputeError = true;
        _isDirty = true;
        _notifiedDirty = false;
        rethrow;
      } finally {
        _isComputing = false;
      }

      _hasComputeError = false;
      _isDirty = false;
      final notify = !_notifiedDirty;
      _notifiedDirty = false;

      // Skip reactive update when value comparator reports no change.
      if (_equals == null || !_equals(_value, resultValue)) {
        _setValueInternal(resultValue, notifyListeners: notify);
      }
      return;
    }

    final tracker = _getTracker();
    tracker.trackReactives = LevitReactiveMiddleware._hasGraphChangeMiddlewares;
    // Verify every read against the last successful order. A changed, repeated,
    // or reordered read falls back to normal dependency capture immediately.
    tracker.expect(_orderedDependencies);
    final previousProxy = _LevitReactiveCore.proxy;
    try {
      _LevitReactiveCore.proxy = tracker;
      late T resultValue;
      try {
        resultValue = _compute();
      } catch (_) {
        _hasComputeError = true;
        _isDirty = true;
        _notifiedDirty = false;
        rethrow;
      } finally {
        _LevitReactiveCore.proxy = previousProxy;
        _isComputing = false;
      }

      _hasComputeError = false;
      _isDirty = false;
      final notify = !_notifiedDirty;
      _notifiedDirty = false;

      if (_equals == null || !_equals(_value, resultValue)) {
        _setValueInternal(resultValue, notifyListeners: notify);
      }

      // A value listener can deactivate or close this computed synchronously.
      if (_isClosed || !_isActive) return;
      if (_staticDeps) _hasStaticGraph = true;
      if (tracker.matches(_orderedDependencies)) {
        // Membership is verified by reads, but upstream depth can still change.
        final deps = _orderedDependencies!;
        if (deps.length == 1) {
          _graphDepth = deps.first.graphDepth + 1;
        } else {
          _recalculateGraphDepth(deps);
        }
      } else {
        _reconcileDependencies(
          tracker.dependencies,
          reactives: tracker.trackReactives ? tracker.reactives : null,
        );
      }
    } finally {
      // Also release on compute, comparator, notification, or middleware errors.
      _releaseTracker(tracker);
    }
  }

  void _ensureFresh() {
    if (_isDirty && !_isComputing) {
      _recompute();
    }
  }

  @override
  @pragma('vm:prefer-inline')
  T get value {
    if (_isActive) {
      _ensureFresh();
      return super.value;
    }

    // Pull-only values do not subscribe. An outer observer already captures
    // their reads; otherwise only graph diagnostics need a temporary tracker.
    if (_capturingCollection ||
        !LevitReactiveMiddleware._hasGraphChangeMiddlewares) {
      return _compute();
    }
    return _readWithGraphCapture();
  }

  // Keep optional diagnostic capture out of ordinary computed read sites.
  @pragma('vm:never-inline')
  T _readWithGraphCapture() {
    final tracker = _DependencyTracker()
      ..trackReactives = LevitReactiveMiddleware._hasGraphChangeMiddlewares;
    LxSpi.proxy = tracker;
    try {
      final result = _compute();
      if (tracker.reactives.isNotEmpty) {
        maybeNotifyGraphChange(tracker.reactives);
      }
      return result;
    } finally {
      LxSpi.proxy = null;
    }
  }

  @override
  void refresh() {
    _isDirty = true;
    if (_isActive && !_isComputing) {
      _ensureFresh();
    }
  }

  @override
  String toString() => isSensitive ? 'LxComputed(***)' : 'LxComputed($value)';
}

/// An asynchronous computed value that reflects state transitions via [LxStatus].
///
/// [LxAsyncComputed] derives state from async operations, automatically tracking
/// dependencies. It exposes the current status (Success, Error, Waiting) of the calculation.
///
/// // Example usage:
/// ```dart
/// final userId = 1.lx;
///
/// // Re-fetches user whenever userId changes
/// final user = LxAsyncComputed(() => fetchUser(userId()));
/// ```
class LxAsyncComputed<T> extends _ComputedBase<LxStatus<T>>
    with _LxAsyncLifecycle<LxStatus<T>> {
  final Future<T> Function() _compute;
  final bool Function(T previous, T current) _equals;
  final bool _showWaiting;

  /// Admission policy for overlapping invalidations.
  final LxAsyncConcurrency concurrency;

  T? _lastComputedValue;
  bool _hasValue = false;
  int _executionId = 0;
  bool _hasProducedResult = false;
  bool _executionRunning = false;
  bool _trailingExecutionRequested = false;

  final bool _staticDeps;
  bool _hasStaticGraph = false;

  /// Base constructor for async computed values.
  LxAsyncComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    bool staticDeps = false,
    T? initial,
    String? name,
    this.concurrency = LxAsyncConcurrency.latest,
  }) : _equals = equals ?? ((a, b) => a == b),
       _showWaiting = showWaiting,
       _staticDeps = staticDeps,
       _lastComputedValue = initial,
       _hasValue = initial != null,
       super(
         initial != null ? LxSuccess<T>(initial) : LxWaiting<T>(),
         name: name,
         equals: equals == null
             ? null
             : (previous, current) {
                 if (previous is LxSuccess<T> && current is LxSuccess<T>) {
                   return equals(previous.value, current.value);
                 }
                 return previous == current;
               },
       );

  @override
  void _onActive() {
    _isActive = true;
    _run();
  }

  @override
  void _onInactive() {
    _isActive = false;
    _executionId++; // Cancel pending
    _trailingExecutionRequested = false;
    _hasStaticGraph = false;
    _cleanupSubscriptions();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || _workCancelled || !_isActive) return;
    _run();
  }

  void _run() {
    if (_isClosed || _workCancelled || !_isActive) return;
    if (concurrency == LxAsyncConcurrency.exhaustLatest && _executionRunning) {
      _trailingExecutionRequested = true;
      return;
    }
    if (concurrency == LxAsyncConcurrency.exhaustLatest) {
      _executionRunning = true;
    }

    final context = _newExecution(
      cancelPrevious: concurrency == LxAsyncConcurrency.latest,
    );
    final myExecutionId = ++_executionId;
    final previous = _value;
    final isInitial = !_hasProducedResult;

    // Dynamic async runs rebuild subscriptions; static graphs keep existing links.
    if (!(_staticDeps && _hasStaticGraph)) {
      _cleanupSubscriptions();
    }

    if (_showWaiting || isInitial) {
      try {
        _setValueInternal(LxWaiting<T>.fromPrevious(previous));
      } catch (_) {
        context._complete();
        _executionContexts.remove(context);
        _finishExecution();
        rethrow;
      }
      if (_isClosed ||
          _workCancelled ||
          !_isActive ||
          myExecutionId != _executionId) {
        context._complete();
        _executionContexts.remove(context);
        _finishExecution();
        return;
      }
    }

    late Future<T> future;
    Object? syncError;
    StackTrace? syncStack;
    bool syncFailed = false;

    // Track dependencies unless static mode has already locked the graph.
    _AsyncLiveTracker? tracker;

    if (_staticDeps && _hasStaticGraph) {
      // Static graph fast path avoids Zone/proxy instrumentation.
      try {
        future = context._run(_compute);
      } catch (e, st) {
        syncError = e;
        syncStack = st;
        syncFailed = true;
      }
    } else {
      // Dynamic mode (or first static run) records live dependencies.
      tracker = _AsyncLiveTracker(
        this,
        myExecutionId,
        trackReactives: LevitReactiveMiddleware._hasGraphChangeMiddlewares,
      );
      final previousProxy = LxSpi.proxy;
      LxSpi.proxy = tracker;

      try {
        future = runZoned(
          () => context._run(_compute),
          zoneValues: {_LevitReactiveCore.asyncComputedTrackerZoneKey: tracker},
          zoneSpecification: _asyncZoneSpec(),
        );
      } catch (e, st) {
        syncError = e;
        syncStack = st;
        syncFailed = true;
      } finally {
        LxSpi.proxy = previousProxy;
        if (tracker.trackReactives) {
          maybeNotifyGraphChange(tracker.reactives);
        }
      }
    }

    // Sync failures produce error status for the current execution.
    if (syncFailed) {
      if (myExecutionId == _executionId) {
        _hasProducedResult = true;
        _hasStaticGraph = _staticDeps;
        _setValueInternal(
          LxError<T>.fromPrevious(syncError!, syncStack!, previous),
        );
      }
      context._complete();
      _executionContexts.remove(context);
      _finishExecution();
      return;
    }

    // Async completion updates status only for the latest execution token.
    _trackWork(
      future
          .then<void>(
            (result) {
              if (myExecutionId == _executionId &&
                  !_isClosed &&
                  !_workCancelled) {
                _hasProducedResult = true;
                // A result listener may detach synchronously and release this graph.
                _hasStaticGraph = _staticDeps;
                _applyResult(result, isInitial: isInitial);

                if (tracker != null) {
                  _notifyDependencyGraph(tracker.reactives);
                }
              }
            },
            onError: (Object e, StackTrace st) {
              if (myExecutionId == _executionId &&
                  !_isClosed &&
                  !_workCancelled) {
                _hasProducedResult = true;
                _hasStaticGraph = _staticDeps;
                _setValueInternal(LxError<T>.fromPrevious(e, st, previous));

                if (tracker != null) {
                  _notifyDependencyGraph(tracker.reactives);
                }
              }
            },
          )
          .whenComplete(_finishExecution),
      context,
    );
  }

  void _finishExecution() {
    if (concurrency != LxAsyncConcurrency.exhaustLatest) return;
    _executionRunning = false;
    if (!_trailingExecutionRequested || _isClosed || !_isActive) return;

    _trailingExecutionRequested = false;
    _run();
  }

  /// Notifies middlewares of dependency graph change.
  void _notifyDependencyGraph(Set<LxReactive> reactives) {
    maybeNotifyGraphChange(reactives);
  }

  void _applyResult(T result, {required bool isInitial}) {
    if (!isInitial && _hasValue && _equals(_lastComputedValue as T, result)) {
      // Preserve reactive update semantics when value is unchanged after waiting or error.
      if (_value is! LxSuccess<T>) {
        _setValueInternal(LxSuccess<T>(result));
      }
      return;
    }

    _lastComputedValue = result;
    _hasValue = true;
    _setValueInternal(LxSuccess<T>(result));
  }

  LxStatus<T> get status => value;

  /// Whether there are active listeners.
  void refresh() => _run();

  @override
  String toString() =>
      isSensitive ? 'LxComputed.async(***)' : 'LxComputed.async($_value)';
}

/// Shared base for computed implementations.
abstract class _ComputedBase<Val> extends LxBase<Val> {
  /// Uses identity-based comparison for faster dependency tracking.
  /// Avoids calling hashCode/== on Stream/Notifier objects.
  LevitReactiveNotifier? _soleDependency;
  Set<LevitReactiveNotifier>? _multipleDependencies;

  Iterable<LevitReactiveNotifier> get _subscriptions =>
      _multipleDependencies ?? [if (_soleDependency case final dep?) dep];

  bool _isSubscribed(LevitReactiveNotifier dep) =>
      identical(_soleDependency, dep) ||
      (_multipleDependencies?.contains(dep) ?? false);

  bool _isActive = false;
  bool _isClosed = false;

  // Owned snapshot, never a pooled tracker's mutable storage. Null means that
  // subscriptions were released and an observed order cannot be reused.
  List<LevitReactiveNotifier>? _orderedDependencies;

  /// Cached hash of reactive dependencies for graph notification deduplication
  int _lastReactivesHash = 0;
  int _lastReactivesLength = 0;

  /// Cached list of reactives to avoid repeated toList() allocations
  List<LxReactive>? _cachedReactivesList;

  /// Stored dependencies from initial build (to avoid double-run in constructor)
  List<LevitReactiveNotifier>? _capturedDeps;
  List<LxReactive>? _capturedReactives;

  _ComputedBase(
    Val initialValue, {
    String? name,
    bool Function(Val previous, Val current)? equals,
  }) : super(
         initialValue,
         onListen: null,
         onCancel: null,
         name: name,
         equals: equals,
       );

  @override
  void _protectedOnActive() {
    super._protectedOnActive();
    _onActive();
  }

  @override
  void _protectedOnInactive() {
    super._protectedOnInactive();
    _lastReactivesHash = 0;
    _lastReactivesLength = 0;
    _onInactive();
  }

  /// Called when the computed value gains its first listener.
  void _onActive();

  /// Called when the computed value loses all listeners.
  void _onInactive();

  /// Callback for dependency notifications.
  void _onDependencyChanged();

  // ---------------------------------------------------------------------------
  // Dependency Management
  // ---------------------------------------------------------------------------

  /// Clears all existing subscriptions and tracking.
  void _cleanupSubscriptions() {
    _orderedDependencies = null;
    final sole = _soleDependency;
    final multiple = _multipleDependencies;
    _soleDependency = null;
    _multipleDependencies = null;
    _graphDepth = 0;
    if (sole != null) _removeSubscription(sole);
    if (multiple != null) {
      for (final dep in multiple) {
        _removeSubscription(dep);
      }
    }
  }

  /// Subscribes to a specific dependency if not already tracked.
  bool _subscribeTo(LevitReactiveNotifier notifier) {
    if (_isSubscribed(notifier)) return false;

    if (LevitReactiveMiddleware._hasListenerMiddlewares) {
      LxSpi.runWithContext(
        LxListenerContext(
          type: 'LxComputed',
          id: identityHashCode(this),
          data: {'name': name, 'runtimeType': runtimeType.toString()},
        ),
        () {
          notifier.addListener(_onDependencyChanged);
        },
      );
    } else {
      notifier.addListener(_onDependencyChanged);
    }
    if (_multipleDependencies case final deps?) {
      deps.add(notifier);
    } else if (_soleDependency case final first?) {
      _multipleDependencies = Set.identity()
        ..add(first)
        ..add(notifier);
      _soleDependency = null;
    } else {
      _soleDependency = notifier;
    }

    final candidateDepth = notifier.graphDepth + 1;
    if (candidateDepth > graphDepth) {
      _graphDepth = candidateDepth;
    }

    return true;
  }

  /// Unsubscribes from a specific dependency.
  void _unsubscribeFrom(LevitReactiveNotifier notifier) {
    if (identical(_soleDependency, notifier)) {
      _soleDependency = null;
    } else {
      _multipleDependencies?.remove(notifier);
    }
    _removeSubscription(notifier);
  }

  void _removeSubscription(LevitReactiveNotifier notifier) {
    if (LevitReactiveMiddleware._hasListenerMiddlewares) {
      LxSpi.runWithContext(
        LxListenerContext(
          type: 'LxComputed',
          id: identityHashCode(this),
          data: {'name': name, 'runtimeType': runtimeType.toString()},
        ),
        () {
          notifier.removeListener(_onDependencyChanged);
        },
      );
    } else {
      notifier.removeListener(_onDependencyChanged);
    }
  }

  void _recalculateGraphDepth(Iterable<LevitReactiveNotifier> dependencies) {
    var nextDepth = 0;
    for (final dependency in dependencies) {
      final dependencyDepth = dependency.graphDepth + 1;
      if (dependencyDepth > nextDepth) {
        nextDepth = dependencyDepth;
      }
    }
    _graphDepth = nextDepth;
  }

  /// Reconciles dependencies for sync computed.
  void _reconcileDependencies(
    Iterable<LevitReactiveNotifier> newDependencies, {
    Iterable<LxReactive>? reactives,
  }) {
    // Captured dependencies are already unique. Small graphs need no temporary
    // hash set; stable graphs need only one membership/depth pass.
    if (_soleDependency == null && _multipleDependencies == null) {
      for (final dep in newDependencies) {
        _subscribeTo(dep);
      }
      // The initial capture is already a privately owned list.
      _orderedDependencies = identical(newDependencies, _capturedDeps)
          ? _capturedDeps
          : newDependencies.toList(growable: false);
      if (reactives != null) maybeNotifyGraphChange(reactives);
      return;
    }
    var same = newDependencies.length == (_multipleDependencies?.length ?? 1);
    var depth = 0;
    for (final dep in newDependencies) {
      if (!_isSubscribed(dep)) same = false;
      final candidate = dep.graphDepth + 1;
      if (candidate > depth) depth = candidate;
    }
    if (same) {
      _graphDepth = depth;
      _orderedDependencies = newDependencies.toList(growable: false);
      return;
    }

    // A large recapture already uses the tracker's dependency set.
    final currentDeps = _subscriptions.toList(growable: false);
    for (final dep in currentDeps) {
      if (!newDependencies.contains(dep)) {
        _unsubscribeFrom(dep);
      }
    }
    for (final dep in newDependencies) {
      _subscribeTo(dep);
    }
    _recalculateGraphDepth(_subscriptions);
    _orderedDependencies = newDependencies.toList(growable: false);

    // Emit graph event after subscriptions match the new dependency set.
    if (reactives != null) {
      maybeNotifyGraphChange(reactives);
    }
  }

  /// Notifies observers of a graph change only if the dependencies have actually changed.
  void maybeNotifyGraphChange(Iterable<LxReactive> reactives) {
    if (reactives.isEmpty) return;

    int hash = 0;
    int length = 0;
    for (final r in reactives) {
      hash ^= identityHashCode(r);
      length++;
    }

    if (hash == _lastReactivesHash && length == _lastReactivesLength) {
      return;
    }

    _lastReactivesHash = hash;
    _lastReactivesLength = length;

    // Reuse list input when available to avoid extra allocations.
    if (reactives is List<LxReactive>) {
      _cachedReactivesList = reactives;
    } else {
      _cachedReactivesList = reactives.toList(growable: false);
    }

    _LevitReactiveMiddlewareChain.applyGraphChange(this, _cachedReactivesList!);
  }

  // ---------------------------------------------------------------------------
  // Reactive API
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _isClosed = true;
    _cleanupSubscriptions();
    return super.close();
  }

  LxStream<R> transform<R>(Stream<R> Function(Stream<Val> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

/// Captures all dependencies into a set (for Sync Computed).
class _DependencyTracker implements LevitReactiveObserver {
  // Small graphs use list storage; larger graphs switch to set semantics.
  final List<LevitReactiveNotifier> _listDeps = [];
  final Set<LevitReactiveNotifier> _setDeps = {};
  bool _useSet = false;
  List<LevitReactiveNotifier>? _expected;
  int _matched = 0;

  final Set<LxReactive> reactives =
      {}; // Graph reporting for middleware/monitoring.
  bool trackReactives = false;

  bool hasCollectionReads = false;

  _DependencyTracker();

  void clear() {
    hasCollectionReads = false;
    // A matching read order never fills the fallback capture containers.
    if (_expected == null) {
      _listDeps.clear();
      if (_useSet) _setDeps.clear();
    }
    _expected = null;
    _matched = 0;
    _useSet = false;
    if (trackReactives) reactives.clear();
  }

  void expect(List<LevitReactiveNotifier>? dependencies) {
    _expected = dependencies;
  }

  bool matches(List<LevitReactiveNotifier>? dependencies) =>
      _expected != null &&
      identical(_expected, dependencies) &&
      _matched == _expected!.length;

  Iterable<LevitReactiveNotifier> get dependencies {
    if (_expected != null) _captureMatchedPrefix();
    return _useSet ? _setDeps : _listDeps;
  }

  void _captureMatchedPrefix() {
    final expected = _expected!;
    _expected = null;
    for (var i = 0; i < _matched; i++) {
      _add(expected[i]);
    }
  }

  void _add(LevitReactiveNotifier dep) {
    final expected = _expected;
    if (expected != null) {
      if (_matched < expected.length && identical(expected[_matched], dep)) {
        _matched++;
        return;
      }
      _captureMatchedPrefix();
    }
    if (_useSet) {
      _setDeps.add(dep);
      return;
    }

    if (_listDeps.contains(dep)) return;

    if (_listDeps.length >= 8) {
      _useSet = true;
      _setDeps.addAll(_listDeps);
      _setDeps.add(dep);
    } else {
      _listDeps.add(dep);
    }
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) => _add(notifier);

  @override
  void addReactive(LxReactive reactive) {
    if (trackReactives) reactives.add(reactive);
  }
}

/// Immediately subscribes to dependencies (for Async Computed).
class _AsyncLiveTracker implements LevitReactiveObserver {
  final LxAsyncComputed _computed;
  final int _executionId;
  final Set<LxReactive> reactives =
      {}; // Graph reporting for middleware/monitoring.
  final bool trackReactives;

  _AsyncLiveTracker(
    this._computed,
    this._executionId, {
    this.trackReactives = false,
  });

  bool get _isCurrent => _computed._executionId == _executionId;

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    if (_isCurrent) _computed._subscribeTo(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    if (trackReactives && _isCurrent) reactives.add(reactive);
  }
}

// Top-level Zone handlers avoid per-run closure allocation in async computed paths.
R _asyncRunHandler<R>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function() f,
) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.run(zone, f);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

R _asyncRunUnaryHandler<R, T>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function(T) f,
  T arg,
) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.runUnary(zone, f, arg);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

R _asyncRunBinaryHandler<R, T1, T2>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function(T1, T2) f,
  T1 arg1,
  T2 arg2,
) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.runBinary(zone, f, arg1, arg2);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

void _asyncScheduleMicrotaskHandler(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  void Function() f,
) {
  parent.scheduleMicrotask(zone, () {
    _LevitReactiveCore._enterAsyncScope();
    try {
      f();
    } finally {
      _LevitReactiveCore._exitAsyncScope();
    }
  });
}

/// Static pre-allocated ZoneSpecification for async tracking.
/// Avoids closure allocation on every async computed run.
final ZoneSpecification _staticAsyncZoneSpec = ZoneSpecification(
  run: _asyncRunHandler,
  runUnary: _asyncRunUnaryHandler,
  runBinary: _asyncRunBinaryHandler,
  scheduleMicrotask: _asyncScheduleMicrotaskHandler,
);

/// Returns the static async zone specification.
/// Kept as a function for API compatibility.
ZoneSpecification _asyncZoneSpec() => _staticAsyncZoneSpec;

/// Extension to create [LxComputed] from a synchronous function.
extension LxFunctionExtension<T> on T Function() {
  /// Transforms this function into a [LxComputed] value.
  ///
  /// ```dart
  /// final count = 0.lx;
  /// final doubled = (() => count.value * 2).lx;
  /// ```
  LxComputed<T> get lx => LxComputed<T>(this);

  /// Transforms this function into a [LxComputed] value with static dependencies.
  ///
  /// The dependency graph is built only once.
  LxComputed<T> get lxStatic => LxComputed<T>(this, staticDeps: true);
}

/// Extension to create [LxAsyncComputed] from an asynchronous function.
extension LxAsyncFunctionExtension<T> on Future<T> Function() {
  /// Transforms this async function into a [LxAsyncComputed] value.
  ///
  /// ```dart
  /// final userId = 1.lx;
  /// final user = (() => fetchUser(userId.value)).lx;
  /// ```
  LxAsyncComputed<T> get lx => LxComputed.async<T>(this);

  /// Transforms this async function into a [LxAsyncComputed] value with static dependencies.
  ///
  /// The dependency graph is built only once.
  LxAsyncComputed<T> get lxStatic =>
      LxComputed.async<T>(this, staticDeps: true);
}
