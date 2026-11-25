part of '../levit_reactive.dart';

// Zone contexts can outlive their callback through escaped asynchronous work.
// Closed contexts are skipped so late work never enters a flushed queue.
class _BatchContext {
  _BatchContext(this.parent, {required this.isAsync});
  final _BatchContext? parent;
  final bool isAsync;
  bool open = true;
  final notifiers = Set<LevitReactiveNotifier>.identity();
  final entries = <(LxReactive, LevitReactiveChange)>[];
}

class _LevitReactiveCore {
  /// Whether to capture stack traces on state changes (expensive).
  static bool captureStackTrace = false;

  static LevitReactiveObserver? _proxy;

  // Last read pair cache avoids duplicate dependency reporting in tight loops.
  static LevitReactiveObserver? _lastReportedObserver;
  static LxReactive? _lastReportedReactive;

  /// The active observer capturing dependencies.
  static LevitReactiveObserver? get proxy => _proxy;

  static set proxy(LevitReactiveObserver? value) {
    if (_proxy == value) return;
    _proxy = value;
    _lastReportedObserver = null;
    _lastReportedReactive = null;
    _updateFastPath();
  }

  // Reuse the backing slots across batches. Drop references as they are
  // delivered so a completed transaction never retains its observers.
  static List<LevitReactiveNotifier?> _batchedNotifiers = List.filled(16, null);
  static int _batchCount = 0;

  @pragma('vm:prefer-inline')
  static void _enqueueBatched(LevitReactiveNotifier notifier) {
    if (notifier._isPendingSyncBatch) return;
    notifier._isPendingSyncBatch = true;
    if (_batchCount == _batchedNotifiers.length) {
      final grown = List<LevitReactiveNotifier?>.filled(_batchCount * 2, null);
      grown.setRange(0, _batchCount, _batchedNotifiers);
      _batchedNotifiers = grown;
    }
    _batchedNotifiers[_batchCount++] = notifier;
  }

  static final List<LevitReactiveNotifier> _propagationQueue = [];

  static bool _isPropagating = false;

  static int _batchDepth = 0;

  /// Whether a batch operation is in progress.
  static bool get isBatching => _batchDepth > 0 || _currentBatch != null;

  static _BatchContext? get _currentBatch {
    var context = Zone.current[_batchZoneKey] as _BatchContext?;
    while (context != null && !context.open) {
      context = context.parent;
    }
    return context;
  }

  static _BatchContext? get _currentAsyncBatch {
    var context = _currentBatch;
    while (context != null) {
      if (context.open && context.isAsync) return context;
      context = context.parent;
    }
    return null;
  }

  /// Internal: Records a change during a batch.
  static void _recordBatchEntry(
    LxReactive reactive,
    LevitReactiveChange change,
  ) {
    // Skip Zone lookup when batch middleware is not registered.
    if (!LevitReactiveMiddleware.hasBatchMiddlewares) return;

    var context = _currentBatch;
    while (context != null) {
      if (context.open) context.entries.add((reactive, change));
      context = context.parent;
    }
  }

  static bool _fastPath = true;

  static void _updateFastPath() {
    _fastPath =
        _proxy == null &&
        _asyncZoneDepth == 0 &&
        _batchDepth == 0 &&
        !_isPropagating;
  }

  // Static comparator avoids per-sort closure allocation during batch flush.
  static int _batchSorter(LevitReactiveNotifier a, LevitReactiveNotifier b) =>
      a._graphDepth.compareTo(b._graphDepth);

  static void _flushGlobalBatch() {
    if (_batchCount == 0) return;

    _batchDepth++;
    _updateFastPath();
    try {
      // Process shallower graph nodes first to keep derived values glitch-free.
      for (var i = 1; i < _batchCount; i++) {
        if (_batchedNotifiers[i - 1]!._graphDepth >
            _batchedNotifiers[i]!._graphDepth) {
          final sorted =
              _batchedNotifiers
                  .take(_batchCount)
                  .cast<LevitReactiveNotifier>()
                  .toList()
                ..sort(_batchSorter);
          _batchedNotifiers.setRange(0, _batchCount, sorted);
          break;
        }
      }

      // Re-entrant notifications can append to this list during iteration.
      int processedCount = 0;
      while (processedCount < _batchCount) {
        final notifier = _batchedNotifiers[processedCount]!;
        _batchedNotifiers[processedCount++] = null;
        notifier._isPendingSyncBatch = false;
        notifier._notifyListeners();
      }

      // Clear only after all appended items were processed.
      _batchCount = 0;
    } finally {
      // Ensure pending flags are reset even when listener code throws.
      for (var i = 0; i < _batchCount; i++) {
        _batchedNotifiers[i]?._isPendingSyncBatch = false;
        _batchedNotifiers[i] = null;
      }
      _batchCount = 0;
      if (_batchedNotifiers.length > 4096) {
        _batchedNotifiers = List.filled(16, null);
      }
      _batchDepth--;
      _updateFastPath();
    }
  }

  /// Internal zone key for async tracking.
  static final Object asyncComputedTrackerZoneKey = Object();

  /// Internal zone key for async batching.
  static final Object _batchZoneKey = Object();

  static int _asyncZoneDepth = 0;

  static void _enterAsyncScope() {
    _asyncZoneDepth++;
    _updateFastPath();
  }

  static void _exitAsyncScope() {
    _asyncZoneDepth--;
    _updateFastPath();
  }

  /// Context data for the current listener registration operation.
  /// Used to associate listeners with high-level constructs (e.g., Widgets).
  static LxListenerContext? listenerContext;

  /// Executes [fn] with [context] set as the current listener context.
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    final previousCheck = listenerContext;
    listenerContext = context;
    try {
      return fn();
    } finally {
      listenerContext = previousCheck;
    }
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Changes are collected and passed to middleware hooks.
  /// Returns the result of [callback], or throws if a middleware cancels.
  static R batch<R>(R Function() callback) {
    if (!LevitReactiveMiddleware.hasBatchMiddlewares) {
      _batchDepth++;
      _updateFastPath();
      try {
        return callback();
      } finally {
        _batchDepth--;
        _updateFastPath();
        if (_batchDepth == 0) {
          _flushGlobalBatch();
        }
      }
    }

    // Middleware path records batch entries in Zone-local storage.
    final context = _BatchContext(_currentBatch, isAsync: false);
    final batchChange = LevitReactiveBatch(context.entries);

    dynamic coreExecution() {
      _batchDepth++;
      _updateFastPath();
      try {
        return runZoned(callback, zoneValues: {_batchZoneKey: context});
      } finally {
        context.open = false;
        _batchDepth--;
        _updateFastPath();
        if (_batchDepth == 0) {
          _flushGlobalBatch();
        }
      }
    }

    // Middleware may wrap execution with interception and cancellation.
    final wrapped = _LevitReactiveMiddlewareChain.applyOnBatch(
      coreExecution,
      batchChange,
    );
    return wrapped() as R;
  }

  /// Batches notifications in this execution context across asynchronous gaps.
  /// Unrelated contexts remain independent; shared values are not isolated.
  static Future<R> batchAsync<R>(Future<R> Function() callback) async {
    final context = _BatchContext(_currentBatch, isAsync: true);
    final change = LevitReactiveBatch(context.entries, isAsync: true);
    Future<R> execute() async {
      _enterAsyncScope();
      try {
        return await runZoned(callback, zoneValues: {_batchZoneKey: context});
      } finally {
        context.open = false;
        _exitAsyncScope();
        try {
          final parent = _currentAsyncBatch;
          if (parent != null) {
            parent.notifiers.addAll(context.notifiers);
          } else {
            // Enter the ordinary ordered synchronous flush once for the full set.
            _batchDepth++;
            _updateFastPath();
            try {
              for (final notifier in context.notifiers) {
                if (!notifier._disposed) {
                  _enqueueBatched(notifier);
                }
              }
            } finally {
              _batchDepth--;
              _updateFastPath();
              if (_batchDepth == 0) _flushGlobalBatch();
            }
          }
        } finally {
          context.notifiers.clear();
        }
      }
    }

    if (!LevitReactiveMiddleware.hasBatchMiddlewares) return execute();
    final wrapped = _LevitReactiveMiddlewareChain.applyOnBatch(execute, change);
    return await (wrapped() as Future<dynamic>);
  }
}

/// The foundational interface for all reactive objects.
///
/// [LxReactive] unifies various reactive sources (variables, futures, streams)
/// under a consistent API for observation and notification.
///
/// Implementations of this interface can be tracked by [LxComputed]
/// and other observers.
abstract interface class LxReadable<T> {
  T get value;
  int get id;
  Stream<T> get stream;
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// A reactive source whose owner may refresh and close it.
abstract interface class LxReactive<T> implements LxReadable<T> {
  /// The current state of the reactive object.
  ///
  /// Reading this property automatically registers the object as a dependency
  /// of the currently active observer (e.g., inside an [LxComputed] builder).
  T get value;

  /// A unique runtime identifier for this reactive instance.
  int get id;

  /// A [Stream] that emits the latest value whenever it updates.
  Stream<T> get stream;

  /// Registers a synchronous [listener] to be called on every value update.
  void addListener(void Function() listener);

  /// Unregisters a previously added [listener].
  void removeListener(void Function() listener);

  /// Triggers a notification listeners without changing the value.
  ///
  /// This ensures that all current listeners are notified of the current state,
  /// and any associated streams emit the latest value.
  void refresh();

  /// Permanently closes the reactive object and releases all internal resources.
  ///
  /// After calling [close], the object should no longer be used.
  Future<void> close();

  /// An optional descriptive name for debugging and profiling.
  String? get name;
  set name(String? value);

  /// The registration key of the owning controller, if applicable.
  String? get ownerId;
  set ownerId(String? value);

  /// Whether this reactive object contains sensitive data.
  ///
  /// If true, the value will be obfuscated in monitor events and logs.
  bool get isSensitive;
  set isSensitive(bool value);
}

/// An observer interface used to automatically track reactive dependencies.
///
/// [LevitReactiveObserver] is implemented by components that need to respond
/// to changes in reactive state without manual subscription management.
abstract class LevitReactiveObserver {
  /// Internal: Registers a [LevitReactiveNotifier] dependency.
  void addNotifier(LevitReactiveNotifier notifier);

  /// Internal: Tracks the reactive source for dependency graph visualization.
  void addReactive(LxReactive reactive) {}
}

/// Optional interface for observers that can canonicalize reactive reads.
abstract interface class LevitReactiveReadResolver {
  LxReactive resolveReactiveRead(LxReactive reactive);
}

/// A low-latency notifier for synchronous reactive updates.
///
/// [LevitReactiveNotifier] is the high-performance core of the reactive system.
/// Unlike [StreamController], it provides zero-latency notifications through
/// synchronous callbacks and implements several optimizations for large-scale
/// reactive graphs.
///
/// ## Performance Optimizations
/// 1.  **Fast Path**: Direct call for single-listener, no-batch scenarios.
/// 2.  **Topological Ordering**: Derived values (like computeds) notify only
///     after their dependencies have updated, preventing "glitches".
/// 3.  **Deduplication**: Prevents duplicate propagation in complex "diamond"
///     dependency patterns.
/// 4.  **Zero-Allocation Snapshots**: Caches listener lists to avoid allocation
///     during notification cycles.
class LevitReactiveNotifier {
  void Function()? _singleListener;
  Set<void Function()>? _setListeners;
  bool _disposed = false;
  // Sync batch deduplication state.
  bool _isPendingSyncBatch = false;
  // Prevent duplicate queue inserts in diamond-shaped dependency graphs.
  bool _isPendingPropagate = false;
  // Reused snapshot of listeners for stable notify loops.
  List<void Function()>? _notifySnapshot;
  int _snapshotGeneration = 0;
  int _setGeneration = 0;

  /// The distance of this notifier from the primary state sources.
  /// Used to ensure correct notification order.
  int _graphDepth = 0;

  /// Returns the current depth in the dependency graph.
  int get graphDepth => _graphDepth;

  LevitReactiveNotifier();

  /// Adds a listener.
  void addListener(void Function() listener) {
    if (_disposed) return;

    // Listener middleware receives context for diagnostics/monitoring.
    if (LevitReactiveMiddleware.hasListenerMiddlewares && this is LxReactive) {
      _LevitReactiveMiddlewareChain.applyOnListenerAdd(
        this as LxReactive,
        _LevitReactiveCore.listenerContext,
      );
    }

    if (_singleListener == null && _setListeners == null) {
      _singleListener = listener;
      return;
    }

    if (_setListeners != null) {
      if (_setListeners!.add(listener)) {
        _setGeneration++;
      }
      return;
    }

    if (_singleListener != null) {
      if (_singleListener == listener) return;
      _setListeners = {_singleListener!, listener};
      _singleListener = null;
      _setGeneration++;
    }
  }

  /// Removes a listener.
  void removeListener(void Function() listener) {
    if (_disposed) return;

    // Listener middleware receives context for diagnostics/monitoring.
    if (LevitReactiveMiddleware.hasListenerMiddlewares && this is LxReactive) {
      _LevitReactiveMiddlewareChain.applyOnListenerRemove(
        this as LxReactive,
        _LevitReactiveCore.listenerContext,
      );
    }

    if (_singleListener != null) {
      if (_singleListener == listener) {
        _singleListener = null;
      }
      return;
    }

    if (_setListeners != null) {
      if (_setListeners!.remove(listener)) {
        _setGeneration++;
      }
      if (_setListeners!.isEmpty) {
        _setListeners = null;
        _notifySnapshot = null; // Hard clear when empty
      }
    }
  }

  /// Notifies all listeners of a change.
  void notify() {
    if (_disposed) return;

    // Direct-call fast path for the most common single-listener case.
    if (_singleListener != null &&
        _setListeners == null &&
        _LevitReactiveCore._fastPath) {
      if (LevitReactiveMiddleware.hasErrorMiddlewares) {
        try {
          _singleListener!();
        } catch (e, s) {
          _LevitReactiveMiddlewareChain.applyOnReactiveError(
            e,
            s,
            this is LxReactive ? this as LxReactive : null,
          );
        }
      } else {
        _singleListener!();
      }
      return;
    }

    // Async batch context defers notifications until async boundary exits.
    if (_LevitReactiveCore._asyncZoneDepth > 0) {
      final asyncBatch = _LevitReactiveCore._currentAsyncBatch;
      if (asyncBatch != null) {
        asyncBatch.notifiers.add(this);
        return;
      }
    }

    // Sync batch context coalesces repeated notifications per notifier.
    if (_LevitReactiveCore._batchDepth > 0) {
      _LevitReactiveCore._enqueueBatched(this);
      return;
    }

    // During propagation, enqueue once to avoid duplicate reactive updates.
    if (_LevitReactiveCore._isPropagating) {
      if (!_isPendingPropagate) {
        _isPendingPropagate = true;
        _LevitReactiveCore._propagationQueue.add(this);
      }
      return;
    }

    // Start iterative propagation cycle.
    _LevitReactiveCore._isPropagating = true;
    _LevitReactiveCore._updateFastPath();
    try {
      _notifyListeners();

      if (_LevitReactiveCore._propagationQueue.isNotEmpty) {
        var i = 0;
        while (i < _LevitReactiveCore._propagationQueue.length) {
          final notifier = _LevitReactiveCore._propagationQueue[i++];
          notifier._isPendingPropagate = false; // Clear before processing
          notifier._notifyListeners();
        }
      }
    } finally {
      _LevitReactiveCore._isPropagating = false;
      _LevitReactiveCore._updateFastPath();
      if (_LevitReactiveCore._propagationQueue.isNotEmpty) {
        // Reset pending flags if propagation exits early.
        for (final n in _LevitReactiveCore._propagationQueue) {
          n._isPendingPropagate = false;
        }
        _LevitReactiveCore._propagationQueue.clear();
      }
    }
  }

  void _notifyListeners() {
    if (_singleListener != null) {
      if (!LevitReactiveMiddleware.hasErrorMiddlewares) {
        _singleListener!();
        return;
      }
      try {
        _singleListener!();
      } catch (e, s) {
        _LevitReactiveMiddlewareChain.applyOnReactiveError(
          e,
          s,
          this is LxReactive ? this as LxReactive : null,
        );
      }
      return;
    }

    // Snapshot avoids concurrent modification while listeners mutate subscriptions.
    var snapshot = _notifySnapshot;
    if (snapshot == null || _snapshotGeneration != _setGeneration) {
      final listeners = _setListeners;
      if (listeners == null || listeners.isEmpty) return;
      snapshot = listeners.toList(growable: false);
      _notifySnapshot = snapshot;
      _snapshotGeneration = _setGeneration;
    }

    final length = snapshot.length;

    // Skip try/catch overhead when no reactive-error middleware is registered.
    if (!LevitReactiveMiddleware.hasErrorMiddlewares) {
      for (var i = 0; i < length; i++) {
        if (_disposed) break;
        snapshot[i]();
      }
      return;
    }

    // Error middleware path preserves loop continuity on listener failures.
    for (var i = 0; i < length; i++) {
      if (_disposed) break;
      try {
        snapshot[i]();
      } catch (e, s) {
        _LevitReactiveMiddlewareChain.applyOnReactiveError(
          e,
          s,
          this is LxReactive ? this as LxReactive : null,
        );
      }
    }
  }

  /// Disposes the notifier.
  ///
  /// Clears all listeners and marks the notifier as disposed.
  void dispose() {
    _disposed = true;
    _singleListener = null;
    _setListeners = null;
  }

  /// Whether the notifier is disposed.
  bool get isDisposed => _disposed;

  /// Whether there are active listeners.
  bool get hasListener {
    return _singleListener != null ||
        (_setListeners != null && _setListeners!.isNotEmpty);
  }

  /// Set the depth (internal use only by computed values).
  @visibleForTesting
  set graphDepth(int value) => _graphDepth = value;
}

/// The primary implementation base for reactive objects.
///
/// [LxBase] provides the core mechanics for value storage, stream propagation,
/// and middleware integration.
abstract class LxBase<T> extends LevitReactiveNotifier
    implements LxReactive<T> {
  static int _nextId = 0;

  @override
  final int id = _nextId++;

  String? _name;
  @override
  String? get name => _name;
  @override
  set name(String? value) {
    if (_name == value) return;
    _name = value;
    _notifyMetadata();
  }

  /// Custom equality function. When null, uses `==`.
  final bool Function(T previous, T current)? equals;

  /// Creates a reactive wrapper around [initial].
  LxBase(
    T initial, {
    this.onListen,
    this.onCancel,
    String? name,
    bool isSensitive = false,
    this.equals,
  }) : _value = initial,
       _name = name,
       _isSensitive = isSensitive {
    if (LevitReactiveMiddleware.hasInitMiddlewares) {
      _LevitReactiveMiddlewareChain.applyOnInit(this);
    }
  }

  /// Compares two values using the custom [equals] function or `==`.
  bool _isEqual(T a, T b) => equals != null ? equals!(a, b) : a == b;

  T _value;
  StreamController<T>? _controller;

  /// Called when the stream is listened to.
  final void Function()? onListen;

  /// Called when the stream is cancelled.
  final void Function()? onCancel;

  bool _isActive = false;
  Set<void Function(bool active)>? _activityObservers;

  String? _ownerId;
  @override
  String? get ownerId => _ownerId;
  @override
  set ownerId(String? value) {
    if (_ownerId == value) return;
    _ownerId = value;
    _notifyMetadata();
  }

  void _notifyMetadata() {
    for (final middleware in LevitReactiveMiddleware._middlewares.toList()) {
      if (middleware is LevitReactiveMetadataObserver) {
        (middleware as LevitReactiveMetadataObserver).onReactiveMetadata(this);
      }
    }
  }

  bool _isSensitive = false;

  @override
  bool get isSensitive => _isSensitive;

  @override
  set isSensitive(bool value) {
    if (_isSensitive == value) return;
    _isSensitive = value;
    _notifyMetadata();
  }

  void _protectedOnActive() {
    onListen?.call();
  }

  void _protectedOnInactive() {
    onCancel?.call();
  }

  void _checkActive() {
    final shouldBeActive = hasListener;
    if (shouldBeActive && !_isActive) {
      _isActive = true;
      _protectedOnActive();
      _notifyActivityObservers(true);
    } else if (!shouldBeActive && _isActive) {
      _isActive = false;
      _protectedOnInactive();
      _notifyActivityObservers(false);
    }
  }

  void _addActivityObserver(void Function(bool active) observer) {
    (_activityObservers ??= <void Function(bool active)>{}).add(observer);
  }

  void _notifyActivityObservers(bool active) {
    final observers = _activityObservers;
    if (observers == null) return;
    for (final observer in observers.toList(growable: false)) {
      observer(active);
    }
  }

  @override
  T get value {
    if (_LevitReactiveCore._fastPath) return _value;

    final proxy = _LevitReactiveCore.proxy;
    if (proxy != null) {
      LxReactive resolved = this;
      if (proxy is LevitReactiveReadResolver) {
        resolved = (proxy as LevitReactiveReadResolver).resolveReactiveRead(
          this,
        );
      }
      if (!identical(resolved, this) && resolved is LxReactive<T>) {
        return resolved.value;
      }
      _reportRead(proxy, resolvedReactive: resolved);
    } else if (_LevitReactiveCore._asyncZoneDepth > 0) {
      final zoneTracker =
          Zone.current[_LevitReactiveCore.asyncComputedTrackerZoneKey];
      if (zoneTracker is LevitReactiveObserver) {
        LxReactive resolved = this;
        if (zoneTracker is LevitReactiveReadResolver) {
          resolved = (zoneTracker as LevitReactiveReadResolver)
              .resolveReactiveRead(this);
        }
        if (!identical(resolved, this) && resolved is LxReactive<T>) {
          return resolved.value;
        }
        _reportRead(zoneTracker, resolvedReactive: resolved);
      }
    }
    return _value;
  }

  /// Notifies listeners without changing the value or triggering middlewares.
  ///
  /// Used by subclasses (like [LxComputed]) to propagate "dirty" state
  /// lazily without triggering a full value update cycle usually associated
  /// with middleware.
  @pragma('vm:prefer-inline')
  void _notifyListenersOnly() {
    if (_LevitReactiveCore._batchDepth > 0 &&
        _LevitReactiveCore._asyncZoneDepth == 0) {
      if (!isDisposed) _LevitReactiveCore._enqueueBatched(this);
      return;
    }
    super.notify();
  }

  void _reportRead(
    LevitReactiveObserver observer, {
    LxReactive? resolvedReactive,
  }) {
    final trackedReactive = resolvedReactive ?? this;
    final LevitReactiveNotifier trackedNotifier =
        trackedReactive is LevitReactiveNotifier
        ? trackedReactive as LevitReactiveNotifier
        : this;

    if (identical(trackedReactive, _LevitReactiveCore._lastReportedReactive) &&
        identical(observer, _LevitReactiveCore._lastReportedObserver)) {
      return;
    }

    _LevitReactiveCore._lastReportedObserver = observer;
    _LevitReactiveCore._lastReportedReactive = trackedReactive;

    observer.addNotifier(trackedNotifier);

    // Reactive graph reporting is opt-in to avoid overhead by default.
    if (LevitReactiveMiddleware.hasGraphChangeMiddlewares) {
      observer.addReactive(trackedReactive);
    }
  }

  // Collections share this publication hook for whole-value writes, binding,
  // middleware restores, and explicit refresh.
  void _publishMutation() => super.notify();

  /// Internal setter for subclasses (Computed, etc.)
  void _setValueInternal(T val, {bool notifyListeners = true}) {
    // Fast path bypasses middleware interception.
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasSetMiddlewares) {
      if (_isEqual(_value, val)) return;
      _value = val;
      _controller?.add(_value);
      if (notifyListeners) {
        _publishMutation();
      }
      return;
    }

    // Slow path builds change payload for middleware and time-travel hooks.
    if (_isEqual(_value, val)) return;

    final oldValue = _value;

    final change = LevitReactiveChange<T>(
      valueType: T,
      oldValue: oldValue,
      newValue: val,
      stackTrace: _LevitReactiveCore.captureStackTrace
          ? StackTrace.current
          : null,
      restore: (v) {
        _value = v;
        _controller?.add(_value);
        if (notifyListeners) {
          _publishMutation();
        }
      },
    );

    // Centralized setter reused by middleware wrappers.
    void performSet(T v) {
      _value = v;
      _controller?.add(_value);
      if (notifyListeners) {
        _publishMutation();
      }
      // Batch middleware expects all writes to be recorded with shared batch id.
      if (_LevitReactiveCore.isBatching) {
        _LevitReactiveCore._recordBatchEntry(this, change);
      }
    }

    final wrapped = _LevitReactiveMiddlewareChain.applyOnSet<T>(
      performSet,
      this,
      change,
    );
    wrapped(val);
  }

  @override
  Stream<T> get stream {
    _controller ??= StreamController<T>.broadcast(
      onListen: () => _checkActive(),
      onCancel: () => _checkActive(),
    );
    return _controller!.stream;
  }

  /// Whether there are active listeners.
  @override
  bool get hasListener {
    return (_controller?.hasListener ?? false) || super.hasListener;
  }

  /// Whether there are active stream listeners.
  bool get _hasStreamListener {
    return _controller?.hasListener ?? false;
  }

  /// Hook for subclasses to clean up binding resources during [close].
  /// Overridden by [_LxBindable].
  FutureOr<void> _cleanupBinding() {}

  Future<void>? _closeFuture;

  /// Stops observation immediately, then drains binding and stream cleanup.
  /// Middleware failures cannot skip cleanup; all failures are reported together
  /// after every cleanup attempt finishes.
  @override
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    final completion = Completer<void>();
    _closeFuture = completion.future;
    List<Future<void>>? pending;
    List<AsyncError>? failures;
    void attempt(FutureOr<void> Function() action) {
      try {
        final result = action();
        if (result is Future) {
          (pending ??= []).add(
            result.then<void>(
              (_) {},
              onError: (Object e, StackTrace s) {
                (failures ??= []).add(AsyncError(e, s));
              },
            ),
          );
        }
      } catch (e, s) {
        (failures ??= []).add(AsyncError(e, s));
      }
    }

    var released = false;
    void release() {
      if (released) return;
      released = true;
      // Stop synchronous observers before awaiting stream cancellation.
      super.dispose();
      attempt(_cleanupBinding);
      attempt(() => _controller?.close());
      attempt(_checkActive);
    }

    try {
      if (LevitReactiveMiddleware.bypassMiddleware ||
          !LevitReactiveMiddleware.hasDisposeMiddlewares) {
        release();
      } else {
        _LevitReactiveMiddlewareChain.applyOnDispose(release, this)();
      }
    } catch (error, stackTrace) {
      (failures ??= []).add(AsyncError(error, stackTrace));
    } finally {
      release();
    }
    void finish() {
      if (failures == null) {
        completion.complete();
      } else {
        completion.completeError(LxCleanupException(failures!));
      }
    }

    if (pending case final operations?) {
      Future.wait(operations).then((_) => finish());
    } else {
      finish();
    }
    return _closeFuture!;
  }

  /// Functor-like call to get value.
  T call() {
    return value;
  }

  /// Triggers a notification without changing the value.
  ///
  /// This also triggers middleware hooks to ensure mutations are tracked.
  void refresh() {
    if (isDisposed) return;
    // Refresh fast path without middleware interception.
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasSetMiddlewares) {
      _controller?.add(_value);
      _publishMutation();
      return;
    }

    // Refresh middleware path emits a synthetic change event.
    final change = LevitReactiveChange<T>(
      valueType: T,
      oldValue: _value,
      newValue: _value,
      stackTrace: _LevitReactiveCore.captureStackTrace
          ? StackTrace.current
          : null,
      restore: (v) {
        _value = v;
        _controller?.add(_value);
        _publishMutation();
      },
    );

    void performRefresh(T v) {
      _controller?.add(
        v,
      ); // Uses v in case middleware modified it (unlikely for refresh but consistent)
      _publishMutation();
      if (_LevitReactiveCore.isBatching) {
        _LevitReactiveCore._recordBatchEntry(this, change);
      }
    }

    final wrapped = _LevitReactiveMiddlewareChain.applyOnSet<T>(
      performRefresh,
      this,
      change,
    );
    wrapped(_value);
  }

  /// Alias for [refresh].
  @override
  void notify() => refresh();

  @override
  void addListener(void Function() listener) {
    super.addListener(listener);
    _checkActive();
  }

  @override
  void removeListener(void Function() listener) {
    super.removeListener(listener);
    _checkActive();
  }

  @override
  String toString() => _value.toString();

  /// Whether the reactive object has been closed/disposed.
  @override
  bool get isDisposed => super.isDisposed;
}

/// Mutation and explicitly owned stream binding for writable reactive values.
mixin _LxMutable<T> on LxBase<T> implements LxAsyncResource {
  void mutate(void Function(T value) mutator) {
    mutator(_value);
    refresh();
  }

  void updateValue(T Function(T val) fn) => _setValueInternal(fn(_value));

  Stream<T>? _boundStream;
  StreamSubscription<T>? _boundSubscription;
  final Set<Future<void>> _bindingCancellations = {};
  final List<AsyncError> _bindingFailures = [];
  bool _bindingClosing = false;
  int _bindingGeneration = 0;

  /// Owns one upstream subscription until [unbind] or [close]. Subscribers use
  /// this value's stable stream, so replacing a binding preserves observation.
  void bind(Stream<T> externalStream) {
    if (isDisposed || _bindingClosing) {
      throw StateError('Cannot bind a closing value.');
    }
    if (identical(_boundStream, externalStream)) return;
    _cancelBinding();
    _boundStream = externalStream;
    final generation = _bindingGeneration;
    _boundSubscription = externalStream.listen(
      (event) {
        if (generation == _bindingGeneration && !isDisposed) {
          _setValueInternal(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (generation != _bindingGeneration || isDisposed) return;
        if (_controller?.hasListener ?? false) {
          _controller!.addError(error, stack);
        } else {
          Zone.current.handleUncaughtError(error, stack);
        }
      },
    );
  }

  void _cancelBinding() {
    _bindingGeneration++;
    _boundStream = null;
    final subscription = _boundSubscription;
    _boundSubscription = null;
    if (subscription == null) return;
    late final Future<void> cancelled;
    cancelled = Future<void>.sync(subscription.cancel)
        .catchError((Object error, StackTrace stack) {
          _bindingFailures.add(AsyncError(error, stack));
        })
        .whenComplete(() => _bindingCancellations.remove(cancelled));
    _bindingCancellations.add(cancelled);
  }

  /// Detaches immediately and waits for all replaced upstream subscriptions.
  Future<void> unbind() {
    _cancelBinding();
    return drain();
  }

  @override
  void requestCancel() {
    _bindingClosing = true;
    _cancelBinding();
  }

  @override
  Future<void> drain() async {
    while (_bindingCancellations.isNotEmpty) {
      await Future.wait(_bindingCancellations.toList());
    }
    if (_bindingFailures.isNotEmpty) throw LxCleanupException(_bindingFailures);
  }

  @override
  Future<void> _cleanupBinding() {
    requestCancel();
    return drain();
  }
}

/// A standard context descriptor for reactive listeners.
///
/// Used to identify "who" is listening to a reactive variable.
class LxListenerContext {
  /// The string representation of the listener's runtime type.
  final String type;

  /// The identity hash code of the listener.
  final int id;

  /// Additional metadata or payload for the listener.
  final Object? data;

  /// Creates a standard listener context.
  const LxListenerContext({required this.type, required this.id, this.data});

  /// Serializes the context to a JSON map.
  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'data': data};

  @override
  String toString() => 'LxContext(type: $type, id: $id, data: $data)';
}

/// Derives an independently owned selector from an observation-only source.
extension LxReadableSelection<T> on LxReadable<T> {
  LxComputed<R> select<R>(R Function(T value) selector) =>
      LxComputed(() => selector(value), staticDeps: true, eager: true);
}
