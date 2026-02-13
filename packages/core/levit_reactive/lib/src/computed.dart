part of '../levit_reactive.dart';

/// A value derived from other reactive objects.
///
/// [LxComputed] automatically tracks its dependencies and re-evaluates
/// when they change. Calculations are lazy and memoized.
///
/// Example:
/// ```dart
/// final firstName = 'John'.lx;
/// final lastName = 'Doe'.lx;
///
/// // Updates only when firstName or lastName changes
/// final fullName = LxComputed(() => '${firstName()} ${lastName()}');
/// ```
class LxComputed<T> extends _ComputedBase<T> {
  final T Function() _compute;
  final bool Function(T previous, T current) _equals;
  bool _isDirty = true;
  bool _isComputing = false;
  // Prevent duplicate reactive updates when dirty-state was already emitted.
  bool _notifiedDirty = false;

  final bool _staticDeps;
  final bool _eager;
  bool _hasStaticGraph = false;

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
  })  : _equals = equals ?? ((a, b) => a == b),
        _staticDeps = staticDeps,
        _eager = eager,
        super(_computeInitial(name, _compute), name: name) {
    _isDirty = true;
    // Initial dependencies are reused on first activation to avoid a second run.
    if (_initialDepStack.isNotEmpty) {
      final tracker = _initialDepStack.removeLast();
      _capturedDeps = tracker.dependencies.toList();
      _capturedReactives =
          tracker.trackReactives ? tracker.reactives.toList() : null;

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
    tracker.trackReactives = LevitReactiveMiddleware.hasGraphChangeMiddlewares;
    tracker.clear();

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
  }) {
    return LxAsyncComputed<T>(
      compute,
      equals: equals,
      showWaiting: showWaiting,
      staticDeps: staticDeps,
      initial: initial,
      name: name,
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
  }) {
    return LxAsyncComputed<T>(
      () async => compute(),
      equals: equals,
      showWaiting: showWaiting,
      staticDeps: staticDeps,
      initial: initial,
      name: name,
    );
  }

  @override
  void _onActive() {
    _isActive = true;
    if (_capturedDeps != null) {
      // Apply constructor-captured graph on first activation.
      _reconcileDependencies(_capturedDeps!, reactives: _capturedReactives);
      _capturedDeps = null;
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
    _isDirty = true;
    _cleanupSubscriptions();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || !_isActive) return;
    if (!_isDirty && !_isComputing) {
      // Stream listeners require eager recompute to push latest value.
      if (_hasStreamListener || _eager) {
        _isDirty = true;
        _recompute();
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
  static final List<_DependencyTracker> _trackerPool = [];

  static _DependencyTracker _getTracker() {
    if (_trackerPool.isEmpty) {
      return _DependencyTracker();
    }
    return _trackerPool.removeLast();
  }

  static void _releaseTracker(_DependencyTracker tracker) {
    tracker.clear();
    _trackerPool.add(tracker);
  }

  void _recompute() {
    if (_isClosed || !_isActive || _isComputing) return;
    _isComputing = true;
    _isDirty = false;

    // Static dependency mode skips graph tracking after first successful capture.
    if (_staticDeps && _hasStaticGraph) {
      T resultValue;
      try {
        resultValue = _compute();
      } catch (e) {
        throw e;
      } finally {
        _isComputing = false;
      }

      // Skip reactive update when value comparator reports no change.
      if (!_equals(super.value, resultValue)) {
        _setValueInternal(resultValue, notifyListeners: !_notifiedDirty);
      }

      _isDirty = false;
      _notifiedDirty = false;
      return;
    }

    // Tracker reuse keeps recompute allocations stable.
    final tracker = _getTracker();
    // Reactive graph capture is only needed when middleware requests it.
    tracker.trackReactives = LevitReactiveMiddleware.hasGraphChangeMiddlewares;
    // Clear defensively in case tracker state leaked from previous use.
    tracker.clear();

    final previousProxy = _LevitReactiveCore.proxy;
    _LevitReactiveCore.proxy = tracker;

    T resultValue;
    try {
      resultValue = _compute();
    } catch (e) {
      throw e;
    } finally {
      _LevitReactiveCore.proxy = previousProxy;
      _isComputing = false;
    }

    // Compare raw values, not wrapped status payloads.
    if (!_equals(super.value, resultValue)) {
      _setValueInternal(resultValue, notifyListeners: !_notifiedDirty);
    }

    _isDirty = false;
    _notifiedDirty = false;

    // Reconcile subscriptions against the latest dependency graph.
    _reconcileDependencies(tracker.dependencies,
        reactives: tracker.trackReactives ? tracker.reactives : null);

    _releaseTracker(tracker);
  }

  void _ensureFresh() {
    if (_isDirty && !_isComputing) {
      _recompute();
    }
  }

  @override
  T get value {
    if (_isActive) {
      _ensureFresh();
      return super.value;
    }

    // Inactive computed values evaluate on demand.
    final existingProxy = Lx.proxy;

    // Without active observer, capture graph only when middleware requires it.
    if (existingProxy == null) {
      if (!LevitReactiveMiddleware.hasGraphChangeMiddlewares) {
        try {
          return _compute();
        } catch (e) {
          throw e;
        }
      }

      final tracker = _DependencyTracker()
        ..trackReactives = LevitReactiveMiddleware.hasGraphChangeMiddlewares;
      Lx.proxy = tracker;

      try {
        T? computationResult;

        try {
          computationResult = _compute();
        } catch (e) {
          throw e;
        }

        // Publish graph changes only when dependency set was observed.
        if (tracker.reactives.isNotEmpty) {
          maybeNotifyGraphChange(tracker.reactives);
        }

        return computationResult as T;
      } finally {
        Lx.proxy = null;
      }
    }

    // Active observer already captures dependencies upstream.
    try {
      return _compute();
    } catch (e) {
      throw e;
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
/// Example:
/// ```dart
/// final userId = 1.lx;
///
/// // Re-fetches user whenever userId changes
/// final user = LxAsyncComputed(() => fetchUser(userId()));
/// ```
class LxAsyncComputed<T> extends _ComputedBase<LxStatus<T>> {
  final Future<T> Function() _compute;
  final bool Function(T previous, T current) _equals;
  final bool _showWaiting;

  T? _lastComputedValue;
  bool _hasValue = false;
  int _executionId = 0;
  bool _hasProducedResult = false;

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
  })  : _equals = equals ?? ((a, b) => a == b),
        _showWaiting = showWaiting,
        _staticDeps = staticDeps,
        _lastComputedValue = initial,
        _hasValue = initial != null,
        super(
          initial != null ? LxSuccess<T>(initial) : LxWaiting<T>(),
          name: name,
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
    _cleanupSubscriptions();
  }

  @override
  void _onDependencyChanged() {
    if (_isClosed || !_isActive) return;
    _run();
  }

  void _run() {
    if (_isClosed || !_isActive) return;

    final myExecutionId = ++_executionId;
    final lastKnown = value.lastValue;
    final isInitial = !_hasProducedResult;

    // Dynamic async runs rebuild subscriptions; static graphs keep existing links.
    if (!(_staticDeps && _hasStaticGraph)) {
      _cleanupSubscriptions();
    }

    if (_showWaiting || isInitial) {
      _setValueInternal(LxWaiting<T>(lastKnown));
    }

    Future<T>? future;
    Object? syncError;
    StackTrace? syncStack;
    bool syncFailed = false;

    // Track dependencies unless static mode has already locked the graph.
    _AsyncLiveTracker? tracker;

    if (_staticDeps && _hasStaticGraph) {
      // Static graph fast path avoids Zone/proxy instrumentation.
      try {
        future = _compute();
      } catch (e, st) {
        syncError = e;
        syncStack = st;
        syncFailed = true;
      }
    } else {
      // Dynamic mode (or first static run) records live dependencies.
      tracker = _AsyncLiveTracker(this, myExecutionId,
          trackReactives: LevitReactiveMiddleware.hasGraphChangeMiddlewares);
      final previousProxy = Lx.proxy;
      Lx.proxy = tracker;

      try {
        future = runZoned(
          () => _compute(),
          zoneValues: {_LevitReactiveCore.asyncComputedTrackerZoneKey: tracker},
          zoneSpecification: _asyncZoneSpec(),
        );
      } catch (e, st) {
        syncError = e;
        syncStack = st;
        syncFailed = true;
      } finally {
        Lx.proxy = previousProxy;
        if (tracker.trackReactives) {
          maybeNotifyGraphChange(tracker.reactives);
        }
      }
    }

    // Sync failures produce error status for the current execution.
    if (syncFailed) {
      if (myExecutionId == _executionId) {
        _hasProducedResult = true;
        _setValueInternal(LxError<T>(syncError!, syncStack!, lastKnown));

        // Static mode locks dependency graph after first completed execution.
        if (_staticDeps && !_hasStaticGraph) {
          _hasStaticGraph = true;
        }
      }
      return;
    }

    // Async completion updates status only for the latest execution token.
    if (future != null) {
      future.then((result) {
        if (myExecutionId == _executionId && !_isClosed) {
          _hasProducedResult = true;
          _applyResult(result, isInitial: isInitial);

          if (tracker != null) {
            _notifyDependencyGraph(tracker.reactives);
          }

          // Static graph is finalized after the first settled execution.
          if (_staticDeps && !_hasStaticGraph) {
            _hasStaticGraph = true;
          }
        }
      }).catchError((e, st) {
        if (myExecutionId == _executionId && !_isClosed) {
          _hasProducedResult = true;
          _setValueInternal(LxError<T>(e, st, lastKnown));

          if (tracker != null) {
            _notifyDependencyGraph(tracker.reactives);
          }

          if (_staticDeps && !_hasStaticGraph) {
            _hasStaticGraph = true;
          }
        }
      });
    }
  }

  /// Notifies middlewares of dependency graph change.
  void _notifyDependencyGraph(Set<LxReactive> reactives) {
    maybeNotifyGraphChange(reactives);
  }

  void _applyResult(T result, {required bool isInitial}) {
    if (!isInitial && _hasValue && _equals(_lastComputedValue as T, result)) {
      // Preserve reactive update semantics when value is unchanged after waiting.
      if (value is LxWaiting<T>) {
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
  String toString() => 'LxComputed.async($status)';
}

/// Shared base for computed implementations.
abstract class _ComputedBase<Val> extends LxBase<Val> {
  /// Uses identity-based comparison for faster dependency tracking.
  /// Avoids calling hashCode/== on Stream/Notifier objects.
  final Map<LevitReactiveNotifier, void> _dependencySubscriptions =
      Map.identity();

  bool _isActive = false;
  bool _isClosed = false;

  /// Cached hash of dependency identities for fast stability check
  int _lastDepsHash = 0;
  int _lastDepsLength = 0;

  /// Cached hash of reactive dependencies for graph notification deduplication
  int _lastReactivesHash = 0;
  int _lastReactivesLength = 0;

  /// Cached list of reactives to avoid repeated toList() allocations
  List<LxReactive>? _cachedReactivesList;

  /// Stored dependencies from initial build (to avoid double-run in constructor)
  List<LevitReactiveNotifier>? _capturedDeps;
  List<LxReactive>? _capturedReactives;

  _ComputedBase(Val initialValue, {String? name})
      : super(initialValue, onListen: null, onCancel: null, name: name);

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
  /// Clears all existing subscriptions and tracking.
  void _cleanupSubscriptions() {
    if (_dependencySubscriptions.isEmpty) {
      graphDepth = 0;
      return;
    }

    // Remove listeners without creating a snapshot list when middleware is disabled.
    if (!LevitReactiveMiddleware.hasListenerMiddlewares) {
      for (final dep in _dependencySubscriptions.keys) {
        dep.removeListener(_onDependencyChanged);
      }
      _dependencySubscriptions.clear();
      graphDepth = 0;
      return;
    }

    if (_dependencySubscriptions.isEmpty) return;

    // Middleware path keeps context attribution while still avoiding snapshot copies.
    for (final notifier in _dependencySubscriptions.keys) {
      Lx.runWithContext(
          LxListenerContext(
            type: 'LxComputed',
            id: identityHashCode(this),
            data: {'name': name, 'runtimeType': runtimeType.toString()},
          ), () {
        notifier.removeListener(_onDependencyChanged);
      });
    }
    _dependencySubscriptions.clear();
    graphDepth = 0;
  }

  /// Subscribes to a specific dependency if not already tracked.
  bool _subscribeTo(LevitReactiveNotifier notifier) {
    if (_dependencySubscriptions.containsKey(notifier)) return false;

    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(
          LxListenerContext(
            type: 'LxComputed',
            id: identityHashCode(this),
            data: {'name': name, 'runtimeType': runtimeType.toString()},
          ), () {
        notifier.addListener(_onDependencyChanged);
      });
    } else {
      notifier.addListener(_onDependencyChanged);
    }
    _dependencySubscriptions[notifier] = null;

    final candidateDepth = notifier.graphDepth + 1;
    if (candidateDepth > graphDepth) {
      graphDepth = candidateDepth;
    }

    return true;
  }

  /// Unsubscribes from a specific dependency.
  void _unsubscribeFrom(LevitReactiveNotifier notifier,
      {bool recalculateDepth = true}) {
    _dependencySubscriptions.remove(notifier);
    if (LevitReactiveMiddleware.hasListenerMiddlewares) {
      Lx.runWithContext(
          LxListenerContext(
            type: 'LxComputed',
            id: identityHashCode(this),
            data: {'name': name, 'runtimeType': runtimeType.toString()},
          ), () {
        notifier.removeListener(_onDependencyChanged);
      });
    } else {
      notifier.removeListener(_onDependencyChanged);
    }
    if (recalculateDepth) {
      _recalculateGraphDepth(_dependencySubscriptions.keys);
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
    graphDepth = nextDepth;
  }

  /// Reconciles dependencies for sync computed.
  void _reconcileDependencies(
    Iterable<LevitReactiveNotifier> newDependencies, {
    Iterable<LxReactive>? reactives,
  }) {
    final depSet = newDependencies is Set<LevitReactiveNotifier>
        ? newDependencies
        : newDependencies.toSet();

    // Hash+length check skips full reconciliation for stable graphs.
    int hash = 0;
    int length = 0;
    for (final dep in depSet) {
      hash ^= identityHashCode(dep);
      length++;
    }

    // Confirm membership to guard against hash collisions.
    if (hash == _lastDepsHash && length == _lastDepsLength) {
      var isSameSet = true;
      for (final dep in depSet) {
        if (!_dependencySubscriptions.containsKey(dep)) {
          isSameSet = false;
          break;
        }
      }
      if (isSameSet) {
        _recalculateGraphDepth(depSet);
        return;
      }
    }

    _lastDepsHash = hash;
    _lastDepsLength = length;

    // Reconcile removed dependencies before adding new ones.
    final currentDeps = _dependencySubscriptions.keys.toList(growable: false);
    for (final dep in currentDeps) {
      if (!depSet.contains(dep)) {
        _unsubscribeFrom(dep, recalculateDepth: false);
      }
    }

    // Subscribe only to newly discovered dependencies.
    for (final dep in depSet) {
      if (!_dependencySubscriptions.containsKey(dep)) _subscribeTo(dep);
    }

    _recalculateGraphDepth(_dependencySubscriptions.keys);

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

    LevitReactiveMiddlewareChain.applyGraphChange(this, _cachedReactivesList!);
  }

  // ---------------------------------------------------------------------------
  // Reactive API
  // ---------------------------------------------------------------------------

  @override
  void close() {
    if (_isClosed) return;
    super.close();
    _isClosed = true;
    _cleanupSubscriptions();
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

  final Set<LxReactive> reactives =
      {}; // Graph reporting for middleware/monitoring.
  bool trackReactives = false;

  _DependencyTracker();

  void clear() {
    _useSet = false;
    _setDeps.clear();
    _listDeps.clear();
    reactives.clear();
  }

  Iterable<LevitReactiveNotifier> get dependencies =>
      _useSet ? _setDeps : _listDeps;

  void _add(LevitReactiveNotifier dep) {
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

  _AsyncLiveTracker(this._computed, this._executionId,
      {this.trackReactives = false});

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
    Zone self, ZoneDelegate parent, Zone zone, R Function() f) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.run(zone, f);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

R _asyncRunUnaryHandler<R, T>(
    Zone self, ZoneDelegate parent, Zone zone, R Function(T) f, T arg) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.runUnary(zone, f, arg);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

R _asyncRunBinaryHandler<R, T1, T2>(Zone self, ZoneDelegate parent, Zone zone,
    R Function(T1, T2) f, T1 arg1, T2 arg2) {
  _LevitReactiveCore._enterAsyncScope();
  try {
    return parent.runBinary(zone, f, arg1, arg2);
  } finally {
    _LevitReactiveCore._exitAsyncScope();
  }
}

void _asyncScheduleMicrotaskHandler(
    Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
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
