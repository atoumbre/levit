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
  // Track if we already notified "Dirty" state to avoid double notification on update
  bool _notifiedDirty = false;

  final bool _staticDeps;
  final bool _eager;
  bool _hasStaticGraph = false;

  // Stack to capture dependencies during initial super() call
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
    // If we captured dependencies during init, store them for _onActive
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

      // We have the value, so not dirty. We will subscribe in _onActive.
      _isDirty = false;
      _releaseTracker(tracker);
    }
  }

  static T _computeInitial<T>(String? name, T Function() compute) {
    // Optimization: Capture dependencies during initial value computation
    final tracker = _getTracker();
    tracker.trackReactives = LevitReactiveMiddleware.hasGraphChangeMiddlewares;
    tracker.clear();

    final previousProxy = _LevitReactiveCore.proxy;
    _LevitReactiveCore.proxy = tracker;

    try {
      return compute();
    } finally {
      _LevitReactiveCore.proxy = previousProxy;
      _initialDepStack.add(tracker);
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
      // First activation: Use dependencies captured during construction
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
      // Eager evaluation for Stream listeners (Push model)
      if (_hasStreamListener || _eager) {
        _isDirty = true;
        _recompute();
        return;
      }

      // Lazy evaluation for Notifier listeners (Pull model)
      _isDirty = true;
      _notifiedDirty = true;
      // Lazy evaluation: Just verify change propagation without recomputing
      _notifyListenersOnly();
    }
  }

  // Pool for dependency trackers to avoid allocations
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

    // OPTIMIZATION: Static Dependencies
    // If staticDeps is true and we already have a graph, skip tracking completely.
    if (_staticDeps && _hasStaticGraph) {
      T resultValue;
      try {
        resultValue = _compute();
      } catch (e) {
        throw e;
      } finally {
        _isComputing = false;
      }

      // Direct equality check
      if (!_equals(super.value, resultValue)) {
        setValueInternal(resultValue, notifyListeners: !_notifiedDirty);
      }

      _isDirty = false;
      _notifiedDirty = false;
      return;
    }

    // Use pooled tracker to avoid allocations.
    final tracker = _getTracker();
    // We only track reactives if middlewares or observers are present
    tracker.trackReactives = LevitReactiveMiddleware.hasGraphChangeMiddlewares;
    // tracker.clear() is called in release, so it's clean (or we clear here to be safe)
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

    // Direct equality check for T values (fixed: was checking LxSuccess<T>)
    if (!_equals(super.value, resultValue)) {
      setValueInternal(resultValue, notifyListeners: !_notifiedDirty);
    }

    _isDirty = false;
    _notifiedDirty = false;

    // Capture dependencies from tracker
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

    // Pull-on-read mode
    final existingProxy = Lx.proxy;

    // If no proxy is listening, track for graph purposes (if middlewares are active)
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

        // Notify middlewares of dependency graph change
        if (tracker.reactives.isNotEmpty) {
          maybeNotifyGraphChange(tracker.reactives);
        }

        return computationResult as T;
      } finally {
        Lx.proxy = null;
      }
    }

    // Existing proxy is active (e.g., LWatch) - just compute
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

    // Async strategy: Clean immediately, subscribe as we go (via Live Tracker).
    // OPTIMIZATION: Skip cleanup if static graph is already established
    if (!(_staticDeps && _hasStaticGraph)) {
      _cleanupSubscriptions();
    }

    if (_showWaiting || isInitial) {
      setValueInternal(LxWaiting<T>(lastKnown));
    }

    Future<T>? future;
    Object? syncError;
    StackTrace? syncStack;
    bool syncFailed = false;

    // We only need a tracker if we are NOT using the static optimization
    // OR if this is the first run of a static computed (to build the graph).
    _AsyncLiveTracker? tracker;

    if (_staticDeps && _hasStaticGraph) {
      // FAST PATH: Static & Ready
      // No Zone, No Tracker, No Proxy
      try {
        future = _compute();
      } catch (e, st) {
        syncError = e;
        syncStack = st;
        syncFailed = true;
      }
    } else {
      // NORMAL PATH: Dynamic OR First Static Run
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

    // Handle Synchronous Error
    if (syncFailed) {
      if (myExecutionId == _executionId) {
        _hasProducedResult = true;
        setValueInternal(LxError<T>(syncError!, syncStack!, lastKnown));

        // Even on error, if we were building a static graph, we lock it?
        // Maybe safer to only lock on success, or lock what we found.
        if (_staticDeps && !_hasStaticGraph) {
          _hasStaticGraph = true;
        }
      }
      return;
    }

    // Handle Future Result
    if (future != null) {
      future.then((result) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          _applyResult(result, isInitial: isInitial);

          if (tracker != null) {
            _notifyDependencyGraph(tracker.reactives);
          }

          // Lock static graph after first successful async completion
          if (_staticDeps && !_hasStaticGraph) {
            _hasStaticGraph = true;
          }
        }
      }).catchError((e, st) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          setValueInternal(LxError<T>(e, st, lastKnown));

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
      // Value unchanged.
      // If we were waiting, flip to Success with same value.
      // If we were waiting, flip to Success with same value.
      if (value is LxWaiting<T>) {
        setValueInternal(LxSuccess<T>(result));
      }
      return;
    }

    _lastComputedValue = result;
    _hasValue = true;
    setValueInternal(LxSuccess<T>(result));
  }

  LxStatus<T> get status => value;

  /// Whether there are active listeners.
  // Note: hasListener is in the abstract base if not overridden or if defined in base.
  // But _ComputedBase is LxBase, which has hasListener.

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
    if (_dependencySubscriptions.isEmpty) return;

    // Optimization: Avoid toList() by separating listener removal from map clearing
    if (!LevitReactiveMiddleware.hasListenerMiddlewares) {
      for (final dep in _dependencySubscriptions.keys) {
        dep.removeListener(_onDependencyChanged);
      }
      _dependencySubscriptions.clear();
      return;
    }

    if (_dependencySubscriptions.isEmpty) return;

    // Optimization: Avoid `toList()` allocation by iterating keys directly.
    // We replicate `_unsubscribeFrom` logic here but skip map removal until the end.
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
    return true;
  }

  /// Unsubscribes from a specific dependency.
  void _unsubscribeFrom(LevitReactiveNotifier notifier) {
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
  }

  /// Reconciles dependencies for sync computed.
  void _reconcileDependencies(
    Iterable<LevitReactiveNotifier> newDependencies, {
    Iterable<LxReactive>? reactives,
  }) {
    // Fast path: Hash-based stability check
    // Compute a fast hash from identity hash codes
    int hash = 0;
    int length = 0;
    for (final dep in newDependencies) {
      hash ^= identityHashCode(dep);
      length++;
    }

    // If hash and length match, graph is stable - skip reconciliation
    if (hash == _lastDepsHash && length == _lastDepsLength) {
      return;
    }

    _lastDepsHash = hash;
    _lastDepsLength = length;

    // Slow path: Full reconciliation
    // 1. Identify Removed: Iterate current keys
    final currentDeps = _dependencySubscriptions.keys.toList(growable: false);
    for (final dep in currentDeps) {
      if (!newDependencies.contains(dep)) _unsubscribeFrom(dep);
    }

    // 2. Identify Added: Iterate new deps
    for (final dep in newDependencies) {
      if (!_dependencySubscriptions.containsKey(dep)) _subscribeTo(dep);
    }

    // 3. Notify middlewares
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

    // Reuse list if input is already a List, otherwise cache the conversion
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
  // Hybrid storage: Use List for small N, Set for large N.
  final List<LevitReactiveNotifier> _listDeps = [];
  final Set<LevitReactiveNotifier> _setDeps = {};
  bool _useSet = false;

  final Set<LxReactive> reactives = {}; // For DevTools graph
  bool trackReactives = false;

  _DependencyTracker();

  void clear() {
    _useSet = false;
    _setDeps.clear();
    _listDeps.clear();
    if (trackReactives) reactives.clear();
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
  final Set<LxReactive> reactives = {}; // For DevTools graph
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

// Top-level handlers to avoid closure allocation on each async computed run
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
