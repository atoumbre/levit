import 'dart:async';

import 'async_types.dart';
import 'core.dart';
import 'global_accessor.dart';
import 'middlewares.dart';
import 'async_status.dart';

// ============================================================================
// LxComputed<T> - Computed Reactive Value
// ============================================================================

/// A synchronous computed reactive value that tracks dependencies automatically.
///
/// Computed values are memoized and lazy. They only re-evaluate when their
/// dependencies change and they are being listened to.
///
/// Use [LxComputed] to derive state from other reactive variables without
/// manually managing subscriptions.
///
/// ## Usage
/// ```dart
/// final count = 0.lx;
/// final doubled = LxComputed(() => count.value * 2);
/// ```
class LxComputed<T> extends _ComputedBase<LxStatus<T>> {
  final T Function() _compute;
  final bool Function(T previous, T current) _equals;
  bool _isDirty = true;
  bool _isComputing = false;
  // Track if we already notified "Dirty" state to avoid double notification on update
  bool _notifiedDirty = false;

  /// Creates a synchronous computed value.
  ///
  /// *   [compute]: The function to calculate the value.
  /// *   [equals]: Optional comparison function to determine if the value has changed.
  LxComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
    String? name,
  })  : _equals = equals ?? ((a, b) => a == b),
        super(_computeSafe(_compute), name: name);

  static LxStatus<T> _computeSafe<T>(T Function() compute) {
    try {
      return LxSuccess(compute());
    } catch (e, st) {
      return LxError(e, st);
    }
  }

  /// Creates an asynchronous computed value.
  ///
  /// *   [compute]: The async function to calculate the value.
  /// *   [showWaiting]: If `true`, the status transitions to [LxWaiting]
  ///     during recomputations. Defaults to `false` (stale-while-revalidate).
  /// *   [initial]: Optional initial value.
  static LxAsyncComputed<T> async<T>(
    Future<T> Function() compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    T? initial,
    String? name,
  }) {
    return LxAsyncComputed<T>(
      compute,
      equals: equals,
      showWaiting: showWaiting,
      initial: initial,
      name: name,
    );
  }

  @override
  void _onActive() {
    _isActive = true;
    _isDirty = true;
    // Initial tracking setup
    _cleanupSubscriptions();
    _recompute();
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
      if (hasStreamListener) {
        _isDirty = true;
        _recompute();
        return;
      }

      // Lazy evaluation for Notifier listeners (Pull model)
      _isDirty = true;
      _notifiedDirty = true;
      // Lazy evaluation: Just verify change propagation without recomputing
      notifyListenersOnly();
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

    // Use pooled tracker to avoid allocations.
    final tracker = _getTracker();
    // We only track reactives if middlewares or observers are present
    tracker.trackReactives = LevitStateMiddleware.hasGraphChangeMiddlewares;
    // tracker.clear() is called in release, so it's clean (or we clear here to be safe)
    tracker.clear();

    final previousProxy = LevitSateCore.proxy;
    LevitSateCore.proxy = tracker;

    T? resultValue;
    Object? error;
    StackTrace? st;
    bool failed = false;

    try {
      resultValue = _compute();
    } catch (e, s) {
      failed = true;
      error = e;
      st = s;
    } finally {
      LevitSateCore.proxy = previousProxy;
      _isComputing = false;
    }

    if (failed) {
      final lastVal = super.value.lastValue;
      setValueInternal(LxError(error!, st!, lastVal),
          notifyListeners: !_notifiedDirty);
      _releaseTracker(tracker);
    } else {
      // Optimization: Check equality before allocating LxSuccess
      final current = super.value;
      // Note: resultValue is T (nullable), current.value is T
      if (current is LxSuccess<T> && _equals(current.value, resultValue as T)) {
        // Values are equal, but we still need to reconcile dependencies
        // effectively "refreshing" graph without emitting update.
      } else {
        setValueInternal(LxSuccess(resultValue as T),
            notifyListeners: !_notifiedDirty);
      }

      _isDirty = false;
      _notifiedDirty = false;

      // Capture dependencies from tracker
      _reconcileDependencies(tracker.dependencies,
          reactives: tracker.trackReactives ? tracker.reactives : null);

      _releaseTracker(tracker);
    }
  }

  void _ensureFresh() {
    if (_isDirty && !_isComputing) {
      _recompute();
    }
  }

  @override
  LxStatus<T> get value {
    if (_isActive) {
      _ensureFresh();
      return super.value;
    }

    // Pull-on-read mode
    final existingProxy = Lx.proxy;

    // If no proxy is listening, track for graph purposes (if middlewares are active)
    if (existingProxy == null) {
      if (!LevitStateMiddleware.hasGraphChangeMiddlewares) {
        try {
          return LxSuccess(_compute());
        } catch (e, st) {
          return LxError(e, st, super.value.lastValue);
        }
      }

      final tracker = _DependencyTracker()
        ..trackReactives = LevitStateMiddleware.hasGraphChangeMiddlewares;
      Lx.proxy = tracker;

      try {
        T? computationResult;
        Object? error;
        StackTrace? stack;

        try {
          computationResult = _compute();
        } catch (e, st) {
          error = e;
          stack = st;
        }

        // Notify middlewares of dependency graph change
        if (tracker.reactives.isNotEmpty) {
          maybeNotifyGraphChange(tracker.reactives);
        }

        if (error != null) {
          return LxError(error, stack, super.value.lastValue);
        }
        return LxSuccess(computationResult as T);
      } finally {
        Lx.proxy = null;
      }
    }

    // Existing proxy is active (e.g., LWatch) - just compute
    try {
      return LxSuccess(_compute());
    } catch (e, st) {
      return LxError(e, st, super.value.lastValue);
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
  String toString() => 'LxComputed($value)';
}

/// An asynchronous computed reactive value.
///
/// Wraps the result in an [LxStatus]. Like [LxComputed], it tracks
/// dependencies automatically, even across async gaps.
///
/// ## Usage
/// ```dart
/// final userId = 1.lx;
/// final user = LxComputed.async(() => fetchUser(userId.value));
/// ```
class LxAsyncComputed<T> extends _ComputedBase<LxStatus<T>> {
  final Future<T> Function() _compute;
  final bool Function(T previous, T current) _equals;
  final bool _showWaiting;

  T? _lastComputedValue;
  bool _hasValue = false;
  int _executionId = 0;
  bool _hasProducedResult = false;

  /// Base constructor for async computed values.
  LxAsyncComputed(
    this._compute, {
    bool Function(T previous, T current)? equals,
    bool showWaiting = false,
    T? initial,
    String? name,
  })  : _equals = equals ?? ((a, b) => a == b),
        _showWaiting = showWaiting,
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
    _cleanupSubscriptions();

    if (_showWaiting || isInitial) {
      setValueInternal(LxWaiting<T>(lastKnown));
    }

    final tracker = _AsyncLiveTracker(this, myExecutionId,
        trackReactives: LevitStateMiddleware.hasGraphChangeMiddlewares);
    final previousProxy = Lx.proxy;
    Lx.proxy = tracker;

    Future<T>? future;
    Object? syncError;
    StackTrace? syncStack;
    bool syncFailed = false;

    // Execute with Zone to capture async dependencies
    try {
      future = runZoned(
        () => _compute(),
        zoneValues: {LevitSateCore.asyncComputedTrackerZoneKey: tracker},
        zoneSpecification: _asyncZoneSpec(),
      );
    } catch (e, st) {
      syncError = e;
      syncStack = st;
      syncFailed = true;
    } finally {
      Lx.proxy = previousProxy;
    }

    // Handle Synchronous Error
    if (syncFailed) {
      if (myExecutionId == _executionId) {
        _hasProducedResult = true;
        setValueInternal(LxError<T>(syncError!, syncStack!, lastKnown));
      }
      return;
    }

    // Handle Future Result
    if (future != null) {
      future.then((result) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          _applyResult(result, isInitial: isInitial);
          _notifyDependencyGraph(tracker.reactives);
        }
      }).catchError((e, st) {
        if (myExecutionId == _executionId) {
          _hasProducedResult = true;
          setValueInternal(LxError<T>(e, st, lastKnown));
          _notifyDependencyGraph(tracker.reactives);
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
  final Map<Object, StreamSubscription?> _dependencySubscriptions = {};

  bool _isActive = false;
  bool _isClosed = false;

  /// Cached hash of dependency identities for fast stability check
  int _lastDepsHash = 0;
  int _lastDepsLength = 0;

  /// Cached hash of reactive dependencies for graph notification deduplication
  int _lastReactivesHash = 0;
  int _lastReactivesLength = 0;

  _ComputedBase(Val initialValue, {String? name})
      : super(initialValue, onListen: null, onCancel: null, name: name);

  @override
  void protectedOnActive() {
    super.protectedOnActive();
    _onActive();
  }

  @override
  void protectedOnInactive() {
    super.protectedOnInactive();
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
    if (_dependencySubscriptions.isEmpty) return;

    final values = _dependencySubscriptions.values.toList();
    for (final sub in values) {
      sub?.cancel();
    }
    final keys = _dependencySubscriptions.keys.toList();
    for (final dep in keys) {
      if (dep is LevitStateNotifier) {
        dep.removeListener(_onDependencyChanged);
      }
    }
    _dependencySubscriptions.clear();
  }

  /// Subscribes to a specific dependency if not already tracked.
  bool _subscribeTo(Object dependency) {
    if (_dependencySubscriptions.containsKey(dependency)) return false;

    if (dependency is Stream) {
      final sub = dependency.listen((_) => _onDependencyChanged());
      _dependencySubscriptions[dependency] = sub;
    } else if (dependency is LevitStateNotifier) {
      dependency.addListener(_onDependencyChanged);
      _dependencySubscriptions[dependency] = null;
    }
    return true;
  }

  /// Unsubscribes from a specific dependency.
  void _unsubscribeFrom(Object dependency) {
    final sub = _dependencySubscriptions.remove(dependency);
    if (sub != null) {
      sub.cancel();
    } else if (dependency is LevitStateNotifier) {
      dependency.removeListener(_onDependencyChanged);
    }
  }

  /// Reconciles dependencies for sync computed.
  void _reconcileDependencies(
    Iterable<Object> newDependencies, {
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

    LevitStateMiddlewareChain.applyGraphChange(
        this, reactives.toList(growable: false));
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

// ---------------------------------------------------------------------------
// Helper Classes
// ---------------------------------------------------------------------------

/// Captures all dependencies into a set (for Sync Computed).
class _DependencyTracker implements LevitStateObserver {
  // Hybrid storage: Use List for small N, Set for large N.
  final List<Object> _listDeps = [];
  final Set<Object> _setDeps = {};
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

  Iterable<Object> get dependencies => _useSet ? _setDeps : _listDeps;

  void _add(Object dep) {
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
  void addStream<T>(Stream<T> stream) => _add(stream);

  @override
  void addNotifier(LevitStateNotifier notifier) => _add(notifier);

  @override
  void addReactive(LxReactive reactive) {
    if (trackReactives) reactives.add(reactive);
  }
}

/// Immediately subscribes to dependencies (for Async Computed).
class _AsyncLiveTracker implements LevitStateObserver {
  final LxAsyncComputed _computed;
  final int _executionId;
  final Set<LxReactive> reactives = {}; // For DevTools graph
  final bool trackReactives;

  _AsyncLiveTracker(this._computed, this._executionId,
      {this.trackReactives = false});

  bool get _isCurrent => _computed._executionId == _executionId;

  @override
  void addStream<T>(Stream<T> stream) {
    if (_isCurrent) _computed._subscribeTo(stream);
  }

  @override
  void addNotifier(LevitStateNotifier notifier) {
    if (_isCurrent) _computed._subscribeTo(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    if (trackReactives && _isCurrent) reactives.add(reactive);
  }
}
// ---------------------------------------------------------------------------
// Static Zone Specification for Async Tracking
// ---------------------------------------------------------------------------

// Top-level handlers to avoid closure allocation on each async computed run
R _asyncRunHandler<R>(
    Zone self, ZoneDelegate parent, Zone zone, R Function() f) {
  LevitSateCore.enterAsyncScope();
  try {
    return parent.run(zone, f);
  } finally {
    LevitSateCore.exitAsyncScope();
  }
}

R _asyncRunUnaryHandler<R, T>(
    Zone self, ZoneDelegate parent, Zone zone, R Function(T) f, T arg) {
  LevitSateCore.enterAsyncScope();
  try {
    return parent.runUnary(zone, f, arg);
  } finally {
    LevitSateCore.exitAsyncScope();
  }
}

R _asyncRunBinaryHandler<R, T1, T2>(Zone self, ZoneDelegate parent, Zone zone,
    R Function(T1, T2) f, T1 arg1, T2 arg2) {
  LevitSateCore.enterAsyncScope();
  try {
    return parent.runBinary(zone, f, arg1, arg2);
  } finally {
    LevitSateCore.exitAsyncScope();
  }
}

void _asyncScheduleMicrotaskHandler(
    Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
  parent.scheduleMicrotask(zone, () {
    LevitSateCore.enterAsyncScope();
    try {
      f();
    } finally {
      LevitSateCore.exitAsyncScope();
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

// =============================================================================
// Extensions
// =============================================================================

/// Extension to create [LxComputed] from a synchronous function.
extension LxFunctionExtension<T> on T Function() {
  /// Transforms this function into a [LxComputed] value.
  ///
  /// ```dart
  /// final count = 0.lx;
  /// final doubled = (() => count.value * 2).lx;
  /// ```
  LxComputed<T> get lx => LxComputed<T>(this);
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
}
