part of '../levit_reactive.dart';

class _LevitReactiveCore {
  /// Whether to capture stack traces on state changes (expensive).
  static bool captureStackTrace = false;

  static LevitReactiveObserver? _proxy;

  // Cache for ultra-fast consecutive read skip
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

  static final Object _batchEntriesKey = Object();

  static final List<LevitReactiveNotifier> _batchedNotifiers = [];

  static final List<LevitReactiveNotifier> _propagationQueue = [];

  static bool _isPropagating = false;

  static int _batchDepth = 0;

  /// Whether a batch operation is in progress.
  static bool get isBatching => _batchDepth > 0;

  /// Internal: Records a change during a batch.
  static void _recordBatchEntry(
      LxReactive reactive, LevitReactiveChange change) {
    // Skip zone lookup if no middlewares (fast path)
    if (!LevitReactiveMiddleware.hasBatchMiddlewares) return;

    final entries = Zone.current[_batchEntriesKey]
        as List<(LxReactive, LevitReactiveChange)>?;

    entries?.add((reactive, change));
  }

  static bool _fastPath = true;

  static void _updateFastPath() {
    _fastPath = _proxy == null &&
        _asyncZoneDepth == 0 &&
        _batchDepth == 0 &&
        !_isPropagating;
    // print('UpdateFastPath: $_fastPath (Depth: $_batchDepth, Async: $_asyncZoneDepth, Prop: $_isPropagating)');
  }

  // Extracted comparator to avoid closure allocation
  static int _batchSorter(LevitReactiveNotifier a, LevitReactiveNotifier b) =>
      a._graphDepth.compareTo(b._graphDepth);

  static void _flushGlobalBatch() {
    if (_batchedNotifiers.isEmpty) return;

    _batchDepth++;
    _updateFastPath();
    try {
      // Topological sort: Process sources (depth 0) before derived values
      // This prevents cascading re-notifications when a source changes
      // before its dependents have been notified.
      if (_batchedNotifiers.length > 1) {
        _batchedNotifiers.sort(_batchSorter);
      }

      // We use a while loop to handle re-entrant adds
      int processedCount = 0;
      while (processedCount < _batchedNotifiers.length) {
        final notifier = _batchedNotifiers[processedCount++];
        notifier._isPendingSyncBatch = false;
        notifier._notifyListeners();
      }

      // Clear after all are processed.
      // Note: If new items are added during _notifyListeners, they append to list and loop continues.
      _batchedNotifiers.clear();
    } finally {
      // Safety: ensure cleared if exception (re-entrant exception?)
      // If exception occurs, we might leave flags execution.
      // But we should clear the list.
      if (_batchedNotifiers.isNotEmpty) {
        for (var n in _batchedNotifiers) {
          n._isPendingSyncBatch = false;
        }
        _batchedNotifiers.clear();
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

    // Wrapped path: collect changes for middleware
    final entries = <(LxReactive, LevitReactiveChange)>[];
    final batchChange = LevitReactiveBatch(entries);

    dynamic coreExecution() {
      _batchDepth++;
      _updateFastPath();
      try {
        return runZoned(
          callback,
          zoneValues: {_batchEntriesKey: entries},
        );
      } finally {
        _batchDepth--;
        _updateFastPath();
        if (_batchDepth == 0) {
          _flushGlobalBatch();
        }
      }
    }

    // Wrap it
    // Note: applyOnBatch returns dynamic Function()
    final wrapped =
        LevitReactiveMiddlewareChain.applyOnBatch(coreExecution, batchChange);
    return wrapped() as R;
  }

  /// Executes [callback] in an asynchronous batch.
  ///
  /// Changes are collected and passed to middleware hooks.
  /// Returns the result of [callback], or throws if a middleware cancels.
  static Future<R> batchAsync<R>(Future<R> Function() callback) async {
    if (!LevitReactiveMiddleware.hasBatchMiddlewares) {
      _batchDepth++;
      _updateFastPath();
      _enterAsyncScope();
      final batchSet = Set<LevitReactiveNotifier>.identity();
      try {
        return await runZoned(
          () => callback(),
          zoneValues: {_batchZoneKey: batchSet},
        );
      } finally {
        _exitAsyncScope();
        _batchDepth--;
        _updateFastPath();
        if (_batchDepth == 0) {
          _flushGlobalBatch();
        }
        for (final notifier in batchSet) {
          notifier.notify();
        }
      }
    }

    // Wrapped path
    final entries = <(LxReactive, LevitReactiveChange)>[];
    final batchChange = LevitReactiveBatch(entries);

    dynamic coreExecution() async {
      _batchDepth++;
      _updateFastPath();
      _enterAsyncScope();

      final batchSet = Set<LevitReactiveNotifier>.identity();
      try {
        return await runZoned(
          () => callback(),
          zoneValues: {
            _batchZoneKey: batchSet,
            _batchEntriesKey: entries,
          },
        );
      } finally {
        _exitAsyncScope();
        _batchDepth--;
        _updateFastPath();
        if (_batchDepth == 0) {
          _flushGlobalBatch();
        }
        for (final notifier in batchSet) {
          notifier.notify();
        }
      }
    }

    final wrapped =
        LevitReactiveMiddlewareChain.applyOnBatch(coreExecution, batchChange);
    return await (wrapped() as Future<dynamic>);
  }
}

/// The foundational interface for all reactive objects.
///
/// [LxReactive] unifies various reactive sources (variables, futures, streams)
/// under a consistent API for observation and notification.
///
/// Implementations of this interface can be tracked by [LxComputed], [LWatch],
/// and other observers.
abstract interface class LxReactive<T> {
  /// The current state of the reactive object.
  ///
  /// Reading this property automatically registers the object as a dependency
  /// of the currently active observer (e.g., inside an [LxComputed] or [LWatch] builder).
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
  void close();

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
  // Batch optimization
  bool _isPendingSyncBatch = false;
  // Propagation deduplication - prevents duplicate entries in diamond dependencies
  bool _isPendingPropagate = false;
  // Cache the listener list to avoid allocation on every notify
  List<void Function()>? _notifySnapshot;

  /// The distance of this notifier from the primary state sources.
  /// Used to ensure correct notification order.
  int _graphDepth = 0;

  /// Returns the current depth in the dependency graph.
  int get graphDepth => _graphDepth;

  LevitReactiveNotifier();

  /// Adds a listener.
  void addListener(void Function() listener) {
    if (_disposed) return;

    // Notify middleware if active
    if (LevitReactiveMiddleware.hasListenerMiddlewares && this is LxReactive) {
      LevitReactiveMiddlewareChain.applyOnListenerAdd(
          this as LxReactive, _LevitReactiveCore.listenerContext);
    }

    if (_singleListener == null && _setListeners == null) {
      _singleListener = listener;
      return;
    }

    if (_setListeners != null) {
      if (_setListeners!.add(listener)) {
        _notifySnapshot = null;
      }
      return;
    }

    if (_singleListener != null) {
      if (_singleListener == listener) return;
      _setListeners = {_singleListener!, listener};
      _singleListener = null;
      _notifySnapshot = null;
    }
  }

  /// Removes a listener.
  void removeListener(void Function() listener) {
    if (_disposed) return;

    // Notify middleware if active
    if (LevitReactiveMiddleware.hasListenerMiddlewares && this is LxReactive) {
      LevitReactiveMiddlewareChain.applyOnListenerRemove(
          this as LxReactive, _LevitReactiveCore.listenerContext);
    }

    if (_singleListener != null) {
      if (_singleListener == listener) {
        _singleListener = null;
      }
      return;
    }

    if (_setListeners != null) {
      if (_setListeners!.remove(listener)) {
        _notifySnapshot = null;
      }
      if (_setListeners!.isEmpty) {
        _setListeners = null;
        _notifySnapshot = null;
        // Optimization: Don't move back to single listener to avoid thrashing?
        // Or if empty, we are fine.
      }
    }
  }

  /// Notifies all listeners of a change.
  void notify() {
    if (_disposed) return;

    // Ultra-fast path: Single listener + no batching/propagation active
    if (_singleListener != null &&
        _setListeners == null &&
        _LevitReactiveCore._fastPath) {
      if (LevitReactiveMiddleware.hasErrorMiddlewares) {
        try {
          _singleListener!();
        } catch (e, s) {
          LevitReactiveMiddlewareChain.applyOnReactiveError(
              e, s, this is LxReactive ? this as LxReactive : null);
        }
      } else {
        _singleListener!();
      }
      return;
    }

    // 0. Handle Async Batching
    if (_LevitReactiveCore._asyncZoneDepth > 0) {
      final asyncBatch = Zone.current[_LevitReactiveCore._batchZoneKey];
      if (asyncBatch is Set<LevitReactiveNotifier>) {
        asyncBatch.add(this);
        return;
      }
    }

    // 1. Handle Sync Batching
    if (_LevitReactiveCore.isBatching) {
      if (!_isPendingSyncBatch) {
        _isPendingSyncBatch = true;
        _LevitReactiveCore._batchedNotifiers.add(this);
      }
      return;
    }

    // 2. Handle Iterative Propagation (Queueing) with deduplication
    // This is critical for diamond dependencies: when A->B and A->C both
    // notify D, we should only process D once.
    if (_LevitReactiveCore._isPropagating) {
      if (!_isPendingPropagate) {
        _isPendingPropagate = true;
        _LevitReactiveCore._propagationQueue.add(this);
      }
      return;
    }

    // 3. Start Propagation Cycle
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
        // Clear flags for any remaining items (safety)
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
        LevitReactiveMiddlewareChain.applyOnReactiveError(
            e, s, this is LxReactive ? this as LxReactive : null);
      }
      return;
    }

    // Use loop over set if consistent? No, modification risk.
    // Use cached snapshot.
    var snapshot = _notifySnapshot;
    if (snapshot == null) {
      final listeners = _setListeners;
      if (listeners == null || listeners.isEmpty) return;
      snapshot = listeners.toList(growable: false);
      _notifySnapshot = snapshot;
    }

    final length = snapshot.length;

    // Optimized loop for common case (no error middleware)
    if (!LevitReactiveMiddleware.hasErrorMiddlewares) {
      for (var i = 0; i < length; i++) {
        if (_disposed) break;
        snapshot[i]();
      }
      return;
    }

    // Safe loop with error handling
    for (var i = 0; i < length; i++) {
      if (_disposed) break;
      try {
        snapshot[i]();
      } catch (e, s) {
        LevitReactiveMiddlewareChain.applyOnReactiveError(
            e, s, this is LxReactive ? this as LxReactive : null);
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

  @override
  String? name;

  /// Creates a reactive wrapper around [initial].
  LxBase(T initial,
      {this.onListen, this.onCancel, this.name, bool isSensitive = false})
      : _value = initial,
        _isSensitive = isSensitive {
    if (LevitReactiveMiddleware.hasInitMiddlewares) {
      LevitReactiveMiddlewareChain.applyOnInit(this);
    }
  }

  T _value;
  StreamController<T>? _controller;
  // Removed _notifier field (this class is now the notifier)

  Stream<T>? _boundStream;
  int _externalListeners = 0;
  StreamSubscription<T>? _activeBoundSubscription;

  /// Called when the stream is listened to.
  final void Function()? onListen;

  /// Called when the stream is cancelled.
  final void Function()? onCancel;

  bool _isActive = false;

  @override
  String? ownerId;

  bool _isSensitive = false;

  @override
  bool get isSensitive => _isSensitive;

  @override
  set isSensitive(bool value) {
    if (_isSensitive == value) return;
    _isSensitive = value;
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
    } else if (!shouldBeActive && _isActive) {
      _isActive = false;
      _protectedOnInactive();
    }
  }

  @override
  T get value {
    if (_LevitReactiveCore._fastPath) return _value;

    final proxy = _LevitReactiveCore.proxy;
    if (proxy != null) {
      _reportRead(proxy);
    } else if (_LevitReactiveCore._asyncZoneDepth > 0) {
      final zoneTracker =
          Zone.current[_LevitReactiveCore.asyncComputedTrackerZoneKey];
      if (zoneTracker is LevitReactiveObserver) {
        _reportRead(zoneTracker);
      }
    }
    return _value;
  }

  /// Notifies listeners without changing the value or triggering middlewares.
  ///
  /// Used by subclasses (like [LxComputed]) to propagate "dirty" state
  /// lazily without triggering a full value update cycle usually associated
  /// with middleware.
  // @protected
  void _notifyListenersOnly() {
    super.notify();
  }

  void _reportRead(LevitReactiveObserver observer) {
    if (identical(this, _LevitReactiveCore._lastReportedReactive) &&
        identical(observer, _LevitReactiveCore._lastReportedObserver)) {
      return;
    }

    _LevitReactiveCore._lastReportedObserver = observer;
    _LevitReactiveCore._lastReportedReactive = this;

    observer.addNotifier(this);

    // DevTools tracking: only enable if explicitly requested via middleware
    if (LevitReactiveMiddleware.hasGraphChangeMiddlewares) {
      observer.addReactive(this);
    }
  }

  /// Internal setter for subclasses (Computed, etc.)
  @visibleForTesting
  void setValueInternal(T val, {bool notifyListeners = true}) {
    // Fast Path (No Middleware)
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasSetMiddlewares) {
      if (_value == val) return;
      _value = val;
      _controller?.add(_value);
      if (notifyListeners) {
        super.notify();
      }
      return;
    }

    // Slow Path (Middleware / Interceptors)
    if (_value == val) return;

    final oldValue = _value;

    final change = LevitReactiveChange<T>(
      timestamp: DateTime.now(),
      valueType: T,
      oldValue: oldValue,
      newValue: val,
      stackTrace:
          _LevitReactiveCore.captureStackTrace ? StackTrace.current : null,
      restore: (v) {
        _value = v;
        _controller?.add(_value);
        if (notifyListeners) {
          super.notify();
        }
      },
    );

    // Core execution function
    void performSet(T v) {
      _value = v;
      _controller?.add(_value);
      if (notifyListeners) {
        super.notify();
      }
      // Record for batch
      if (_LevitReactiveCore.isBatching) {
        _LevitReactiveCore._recordBatchEntry(this, change);
      }
    }

    final wrapped =
        LevitReactiveMiddlewareChain.applyOnSet<T>(performSet, this, change);
    wrapped(val);
  }

  @override
  Stream<T> get stream {
    if (_boundStream != null) return _boundStream!;
    _controller ??= StreamController<T>.broadcast(
        onListen: () => _checkActive(), onCancel: () => _checkActive());
    return _controller!.stream;
  }

  /// Whether there are active listeners.
  @override
  bool get hasListener {
    // Discount our own internal subscription if present
    int effectiveExternal = _externalListeners;
    if (_activeBoundSubscription != null) effectiveExternal--;

    return (_controller?.hasListener ?? false) ||
        super.hasListener ||
        effectiveExternal > 0;
  }

  /// Whether there are active stream listeners.
  bool get _hasStreamListener {
    // Discount our own internal subscription if present
    int effectiveExternal = _externalListeners;
    if (_activeBoundSubscription != null) effectiveExternal--;

    return (_controller?.hasListener ?? false) || effectiveExternal > 0;
  }

  /// Binds an external stream to this reactive variable.
  void bind(Stream<T> externalStream) {
    if (_boundStream != null && _boundStream == externalStream) return;

    unbind();

    _boundStream = externalStream.map((event) {
      _value = event;
      _controller?.add(event);
      super.notify();
      return event;
    }).transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, st, sink) {
          _controller?.addError(error, st);
          sink.addError(error, st);
        },
      ),
    ).asBroadcastStream(
      onListen: (sub) {
        _externalListeners++;
        _checkActive();
      },
      onCancel: (subscription) {
        _externalListeners--;
        _checkActive();
        subscription.cancel();
      },
    );

    if (hasListener) {
      _activeBoundSubscription = _boundStream!.listen((_) {});
    }
  }

  /// Unbinds any external stream.
  void unbind() {
    _activeBoundSubscription?.cancel();
    _activeBoundSubscription = null;
    _boundStream = null;
    _externalListeners = 0;
    _checkActive();
  }

  /// Creates a specific selection of the state that only updates when the selected value changes.
  ///
  /// This is useful for optimizing rebuilds when using large state objects.
  /// The selector receives the current value of the state.
  ///
  /// Example:
  /// ```dart
  /// final state = {'count': 0, 'data': 'foo'}.lx;
  /// final count = state.select((val) => val['count']);
  /// ```
  LxComputed<R> select<R>(R Function(T value) selector) {
    return LxComputed<R>(
      () => selector(value),
      staticDeps: true,
      eager: true,
      name: name != null ? '$name.select' : null,
    );
  }

  @override
  void close() {
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasDisposeMiddlewares) {
      unbind();
      _controller?.close();
      super.dispose();
      _checkActive();
    } else {
      final wrapped = LevitReactiveMiddlewareChain.applyOnDispose(() {
        unbind();
        _controller?.close();
        super.dispose();
        _checkActive();
      }, this);
      wrapped();
    }
  }

  /// Functor-like call to get value.
  T call() {
    // Return the current value
    return value;
  }

  /// Triggers a notification without changing the value.
  ///
  /// This also triggers middleware hooks to ensure mutations are tracked.
  void refresh() {
    // Fast Path
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasSetMiddlewares) {
      _controller?.add(_value);
      super.notify();
      return;
    }

    // Slow Path
    final change = LevitReactiveChange<T>(
      timestamp: DateTime.now(),
      valueType: T,
      oldValue: _value,
      newValue: _value,
      stackTrace:
          _LevitReactiveCore.captureStackTrace ? StackTrace.current : null,
      restore: (v) {
        _value = v;
        _controller?.add(_value);
        super.notify();
      },
    );

    void performRefresh(T v) {
      _controller?.add(
          v); // Uses v in case middleware modified it (unlikely for refresh but consistent)
      super.notify();
      if (_LevitReactiveCore.isBatching) {
        _LevitReactiveCore._recordBatchEntry(this, change);
      }
    }

    final wrapped = LevitReactiveMiddlewareChain.applyOnSet<T>(
        performRefresh, this, change);
    wrapped(_value);
  }

  /// Alias for [refresh].
  @override
  void notify() => refresh();

  /// Mutates the value in place and triggers a refresh.
  void mutate(void Function(T value) mutator) {
    mutator(_value);
    refresh();
  }

  @override
  void addListener(void Function() listener) {
    super.addListener(listener);
    _checkActive();

    if (_isActive && _boundStream != null && _activeBoundSubscription == null) {
      _activeBoundSubscription = _boundStream!.listen((_) {});
    }
  }

  @override
  void removeListener(void Function() listener) {
    super.removeListener(listener);
    _checkActive();

    if (!hasListener) {
      _activeBoundSubscription?.cancel();
      _activeBoundSubscription = null;
    }
  }

  /// Updates the value using a transformation function.
  void updateValue(T Function(T val) fn) {
    setValueInternal(fn(_value));
  }

  @override
  String toString() => _value.toString();

  /// Whether the reactive object has been closed/disposed.
  @override
  bool get isDisposed => super.isDisposed;
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
  const LxListenerContext({
    required this.type,
    required this.id,
    this.data,
  });

  /// Serializes the context to a JSON map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'data': data,
      };

  @override
  String toString() => 'LxContext(type: $type, id: $id, data: $data)';
}
