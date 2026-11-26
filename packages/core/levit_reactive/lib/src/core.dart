part of 'reactive_library.dart';

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
    _updateFastRead();
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

  static final List<LevitReactiveNotifier?> _propagationQueue = [];

  static bool _isPropagating = false;

  static int _batchDepth = 0;

  /// Whether a batch operation is in progress.
  static bool get isBatching =>
      _batchDepth > 0 || (_asyncBatchDepth > 0 && _currentBatch != null);

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
    if (!LevitReactiveMiddleware._hasBatchMiddlewares) return;

    var context = _currentBatch;
    while (context != null) {
      if (context.open) context.entries.add((reactive, change));
      context = context.parent;
    }
  }

  static bool _fastRead = true;
  static bool _fastNotify = true;

  static void _updateFastRead() {
    _fastRead = _proxy == null && _asyncTrackerDepth == 0;
  }

  static void _updateFastNotify() {
    _fastNotify = _asyncBatchDepth == 0 && _batchDepth == 0 && !_isPropagating;
  }

  static void _flushGlobalBatch() {
    if (_batchCount == 0) return;

    _batchDepth++;
    _updateFastNotify();
    try {
      // Process shallower graph nodes first, including nodes appended during
      // flush, so derived values stay glitch-free without duplicate emissions.
      var head = 0;
      var remaining = _batchCount;
      while (remaining > 0) {
        while (head < _batchCount && _batchedNotifiers[head] == null) {
          head++;
        }
        if (head >= _batchCount) break;
        var minIdx = head;
        var minDepth = _batchedNotifiers[head]!._graphDepth;
        if (minDepth > 0) {
          for (var i = head + 1; i < _batchCount; i++) {
            final candidate = _batchedNotifiers[i];
            if (candidate != null && candidate._graphDepth < minDepth) {
              minDepth = candidate._graphDepth;
              minIdx = i;
              if (minDepth == 0) break;
            }
          }
        }
        final notifier = _batchedNotifiers[minIdx]!;
        _batchedNotifiers[minIdx] = null;
        remaining--;
        if (minIdx == head) head++;
        final countBefore = _batchCount;
        notifier._isPendingSyncBatch = false;
        notifier._propagateNotify();
        remaining += _batchCount - countBefore;
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
      _updateFastNotify();
    }
  }

  /// Internal zone key for async tracking.
  static final Object asyncComputedTrackerZoneKey = Object();

  /// Internal zone key for async batching.
  static final Object _batchZoneKey = Object();

  static int _asyncTrackerDepth = 0;
  static int _asyncBatchDepth = 0;

  static void _enterAsyncScope() {
    _asyncTrackerDepth++;
    _updateFastRead();
  }

  static void _exitAsyncScope() {
    _asyncTrackerDepth--;
    _updateFastRead();
  }

  static void _enterAsyncBatch() {
    _asyncBatchDepth++;
    _updateFastNotify();
  }

  static void _exitAsyncBatch() {
    _asyncBatchDepth--;
    _updateFastNotify();
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
    if (!LevitReactiveMiddleware._hasBatchMiddlewares) {
      _batchDepth++;
      _updateFastNotify();
      try {
        return callback();
      } finally {
        _batchDepth--;
        _updateFastNotify();
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
      _updateFastNotify();
      try {
        return runZoned(callback, zoneValues: {_batchZoneKey: context});
      } finally {
        context.open = false;
        _batchDepth--;
        _updateFastNotify();
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
      _enterAsyncBatch();
      try {
        return await runZoned(callback, zoneValues: {_batchZoneKey: context});
      } finally {
        context.open = false;
        _exitAsyncBatch();
        try {
          final parent = _currentAsyncBatch;
          if (parent != null) {
            parent.notifiers.addAll(context.notifiers);
          } else {
            // Enter the ordinary ordered synchronous flush once for the full set.
            _batchDepth++;
            _updateFastNotify();
            try {
              for (final notifier in context.notifiers) {
                if (!notifier._disposed) {
                  _enqueueBatched(notifier);
                }
              }
            } finally {
              _batchDepth--;
              _updateFastNotify();
              if (_batchDepth == 0) _flushGlobalBatch();
            }
          }
        } finally {
          context.notifiers.clear();
        }
      }
    }

    if (!LevitReactiveMiddleware._hasBatchMiddlewares) return execute();
    final wrapped = _LevitReactiveMiddlewareChain.applyOnBatch(execute, change);
    return await (wrapped() as Future<dynamic>);
  }
}

/// The foundational read-only interface for reactive sources.
///
/// [LxReadable] unifies reactive sources (variables, computed values,
/// collections, collection entries, resources, futures, and streams) under a
/// consistent API for observation and notification.
///
/// Implementations of this interface can be tracked by [LxComputed],
/// [LxWorker], and Flutter observers without exposing mutating or ownership
/// controls.
///
/// {@category Reactive State}
abstract interface class LxReadable<T> {
  /// The current value of this reactive source.
  ///
  /// Reading this getter registers the source as a dependency of the currently
  /// active observer (for example inside an [LxComputed]).
  T get value;

  /// A unique runtime identifier for this reactive source.
  int get id;

  /// A broadcast [Stream] that emits updates as the value changes.
  Stream<T> get stream;

  /// Registers a synchronous [listener] to be called on value updates.
  void addListener(void Function() listener);

  /// Unregisters a previously registered [listener].
  void removeListener(void Function() listener);
}

/// A reactive source whose owner may refresh and close it.
///
/// {@category Reactive State}
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

  /// Triggers a notification to listeners without changing the value.
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

  /// Updates the descriptive [name] and notifies metadata observers.
  set name(String? value);

  /// The registration key of the owning scope resource, if applicable.
  String? get ownerId;

  /// Updates the owning [ownerId] and notifies metadata observers.
  set ownerId(String? value);

  /// Whether this reactive object contains sensitive data.
  ///
  /// If `true`, the value is obfuscated in monitor events and logs.
  bool get isSensitive;

  /// Updates the [isSensitive] flag and notifies metadata observers.
  set isSensitive(bool value);
}

/// An observer interface used to automatically track reactive dependencies.
///
/// [LevitReactiveObserver] is implemented by components that need to respond
/// to changes in reactive state without manual subscription management.
///
/// {@category SPI}
abstract class LevitReactiveObserver {
  /// Registers a [LevitReactiveNotifier] dependency with this observer.
  void addNotifier(LevitReactiveNotifier notifier);

  /// Tracks the [LxReactive] source for dependency graph visualization.
  void addReactive(LxReactive reactive) {}
}

/// Optional SPI interface for observers that canonicalize reactive reads.
///
/// {@category SPI}
abstract interface class LevitReactiveReadResolver {
  /// Returns the canonical [LxReactive] to attribute a read of [reactive] to.
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
///
/// {@category SPI}
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

  /// Monotonic mutation counter used by inactive computed values to detect
  /// upstream changes between construction and first activation.
  int _version = 0;

  /// Returns the current depth in the dependency graph.
  int get graphDepth => _graphDepth;

  /// Creates a reactive notifier with no initial listeners.
  LevitReactiveNotifier();

  /// Adds a listener.
  void addListener(void Function() listener) {
    if (_disposed) return;

    // Listener middleware receives context for diagnostics/monitoring.
    if (LevitReactiveMiddleware._hasListenerMiddlewares && this is LxReactive) {
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
    if (LevitReactiveMiddleware._hasListenerMiddlewares && this is LxReactive) {
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

    final listeners = _setListeners;
    if (listeners != null) {
      if (listeners.remove(listener)) {
        _setGeneration++;
      }
      if (listeners.length == 1) {
        _singleListener = listeners.first;
        _setListeners = null;
        _notifySnapshot = null;
      }
    }
  }

  /// Notifies all listeners of a change.
  void notify() {
    if (_disposed) return;
    _version++;

    // Direct-call fast path for zero-listener and single-listener cases.
    if (_LevitReactiveCore._fastNotify) {
      final listener = _singleListener;
      if (listener == null) {
        if (_setListeners == null) return;
      } else {
        if (LevitReactiveMiddleware._hasErrorMiddlewares) {
          try {
            listener();
          } catch (e, s) {
            _LevitReactiveMiddlewareChain.applyOnReactiveError(
              e,
              s,
              this is LxReactive ? this as LxReactive : null,
            );
          }
        } else {
          listener();
        }
        return;
      }
    }

    // Async batch context defers notifications until async boundary exits.
    if (_LevitReactiveCore._asyncBatchDepth > 0) {
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
    _LevitReactiveCore._updateFastNotify();
    try {
      _notifyListeners();

      final queue = _LevitReactiveCore._propagationQueue;
      if (queue.isNotEmpty) {
        var head = 0;
        var remaining = queue.length;
        while (remaining > 0) {
          while (head < queue.length && queue[head] == null) {
            head++;
          }
          if (head >= queue.length) break;
          var minIdx = head;
          var minDepth = queue[head]!._graphDepth;
          if (minDepth > 0) {
            for (var i = head + 1; i < queue.length; i++) {
              final candidate = queue[i];
              if (candidate != null && candidate._graphDepth < minDepth) {
                minDepth = candidate._graphDepth;
                minIdx = i;
                if (minDepth == 0) break;
              }
            }
          }
          final notifier = queue[minIdx]!;
          queue[minIdx] = null;
          remaining--;
          if (minIdx == head) head++;
          final lengthBefore = queue.length;
          notifier._isPendingPropagate = false; // Clear before processing
          notifier._propagateNotify();
          remaining += queue.length - lengthBefore;
        }
      }
    } finally {
      _LevitReactiveCore._isPropagating = false;
      _LevitReactiveCore._updateFastNotify();
      if (_LevitReactiveCore._propagationQueue.isNotEmpty) {
        // Reset pending flags if propagation exits early.
        for (final n in _LevitReactiveCore._propagationQueue) {
          n?._isPendingPropagate = false;
        }
        _LevitReactiveCore._propagationQueue.clear();
      }
    }
  }

  /// Hook invoked when dequeuing from batch or propagation queues.
  /// Overridden by [LxComputed] to run deferred eager recomputations in
  /// topological order.
  void _propagateNotify() => _notifyListeners();

  void _notifyListeners() {
    if (_singleListener != null) {
      if (!LevitReactiveMiddleware._hasErrorMiddlewares) {
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
    if (!LevitReactiveMiddleware._hasErrorMiddlewares) {
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
    _notifySnapshot = null;
  }

  /// Whether the notifier is disposed.
  bool get isDisposed => _disposed;

  /// Whether there are active listeners.
  bool get hasListener {
    return _singleListener != null ||
        (_setListeners != null && _setListeners!.isNotEmpty);
  }
}

/// The primary implementation base for reactive objects.
///
/// [LxBase] provides the core mechanics for value storage, stream propagation,
/// and middleware integration.
///
/// {@category SPI}
abstract class LxBase<T> extends LevitReactiveNotifier
    implements LxReactive<T> {
  static int _nextId = 0;

  @override
  final int id = _nextId++;

  /// Exposes this reactive object as a read-only [LxReadable] interface.
  ///
  /// Useful for exposing public state from a controller while keeping setters
  /// and disposal private.
  LxReadable<T> get asReadable => this;

  String? _name;
  @override
  String? get name => _name;
  @override
  set name(String? value) {
    if (_name == value) return;
    _name = value;
    _notifyMetadata();
  }

  /// Custom equality function. When `null`, uses `==`.
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
    if (LevitReactiveMiddleware._hasInitMiddlewares) {
      _LevitReactiveMiddlewareChain.applyOnInit(this);
    }
  }

  /// Compares two values using the custom [equals] function or `==`.
  bool _isEqual(T a, T b) => equals != null ? equals!(a, b) : a == b;

  T _value;
  StreamController<T>? _controller;

  /// Called when the first listener (via [addListener] or [stream]) attaches.
  final void Function()? onListen;

  /// Called when the last listener (both direct and [stream]) detaches.
  final void Function()? onCancel;

  bool _isActive = false;

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
    } else if (!shouldBeActive && _isActive) {
      _isActive = false;
      _protectedOnInactive();
    }
  }

  @override
  T get value {
    if (_LevitReactiveCore._fastRead) return _value;

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
    } else if (_LevitReactiveCore._asyncTrackerDepth > 0) {
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
        _LevitReactiveCore._asyncBatchDepth == 0) {
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
    if (LevitReactiveMiddleware._hasGraphChangeMiddlewares) {
      observer.addReactive(trackedReactive);
    }
  }

  // Collections share this publication hook for whole-value writes, binding,
  // middleware restores, and explicit refresh.
  void _publishMutation() => super.notify();

  /// Internal setter for subclasses (Computed, etc.)
  void _setValueInternal(T val, {bool notifyListeners = true}) {
    final recordBatch =
        LevitReactiveMiddleware._hasBatchMiddlewares &&
        _LevitReactiveCore.isBatching;
    // Fast path bypasses middleware interception.
    if (LevitReactiveMiddleware.bypassMiddleware ||
        (!LevitReactiveMiddleware._hasSetMiddlewares && !recordBatch)) {
      if (_isEqual(_value, val)) return;
      _value = val;
      _version++;
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
      stackTrace:
          _LevitReactiveCore.captureStackTrace ? StackTrace.current : null,
      restore: (v) {
        _value = v;
        _version++;
        _controller?.add(_value);
        if (notifyListeners) {
          _publishMutation();
        }
      },
    );

    // Centralized setter reused by middleware wrappers.
    void performSet(T v) {
      _value = v;
      _version++;
      _controller?.add(_value);
      if (notifyListeners) {
        _publishMutation();
      }
      // Batch middleware expects all writes to be recorded with shared batch id.
      if (_LevitReactiveCore.isBatching) {
        _LevitReactiveCore._recordBatchEntry(this, change);
      }
    }

    if (!LevitReactiveMiddleware._hasSetMiddlewares) {
      performSet(val);
      return;
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
  /// Overridden by [LxVar] and precise collections.
  FutureOr<void> _cleanupBinding() {}

  Future<void>? _closeFuture;

  /// Closes synchronously when possible, returning `null` if finished or a
  /// [Future] when asynchronous cleanup is required.
  FutureOr<void> _closeSyncOrAsync() {
    if (_closeFuture != null) return _closeFuture!;
    if (_controller == null &&
        onCancel == null &&
        (LevitReactiveMiddleware.bypassMiddleware ||
            !LevitReactiveMiddleware._hasDisposeMiddlewares)) {
      super.dispose();
      final binding = _cleanupBinding();
      if (binding is! Future) {
        _checkActive();
        _closeFuture = Future<void>.value();
        return null;
      }
      final completion = Completer<void>();
      _closeFuture = completion.future;
      _checkActive();
      binding.then<void>(
        (_) => completion.complete(),
        onError: (Object e, StackTrace s) {
          completion.completeError(LxCleanupException([AsyncError(e, s)]), s);
        },
      );
      return _closeFuture!;
    }
    return _closeFull();
  }

  /// Stops observation immediately, then drains binding and stream cleanup.
  /// Middleware failures cannot skip cleanup; all failures are reported together
  /// after every cleanup attempt finishes.
  @override
  Future<void> close() {
    final result = _closeSyncOrAsync();
    if (result is Future<void>) return result;
    return _closeFuture!;
  }

  Future<void> _closeFull() {
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
          !LevitReactiveMiddleware._hasDisposeMiddlewares) {
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
    final recordBatch =
        LevitReactiveMiddleware._hasBatchMiddlewares &&
        _LevitReactiveCore.isBatching;
    // Refresh fast path without middleware interception.
    if (LevitReactiveMiddleware.bypassMiddleware ||
        (!LevitReactiveMiddleware._hasSetMiddlewares && !recordBatch)) {
      _controller?.add(_value);
      _publishMutation();
      return;
    }

    // Refresh middleware path emits a synthetic change event.
    final change = LevitReactiveChange<T>(
      valueType: T,
      oldValue: _value,
      newValue: _value,
      stackTrace:
          _LevitReactiveCore.captureStackTrace ? StackTrace.current : null,
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

    if (!LevitReactiveMiddleware._hasSetMiddlewares) {
      performRefresh(_value);
      return;
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
  String toString() => isSensitive ? '***' : _value.toString();

  /// Whether the reactive object has been closed/disposed.
  @override
  bool get isDisposed => super.isDisposed;
}

/// A standard context descriptor for reactive listeners.
///
/// Used to identify "who" is listening to a reactive variable.
///
/// {@category Reactive State}
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
///
/// {@category Reactive State}
extension LxReadableSelection<T> on LxReadable<T> {
  /// Creates an eager, `staticDeps: true` [LxComputed] projecting this source
  /// through [selector].
  ///
  /// The caller owns the returned [LxComputed] and must `own(...)` or
  /// `await close()` it when no longer needed.
  LxComputed<R> select<R>(R Function(T value) selector) =>
      LxComputed(() => selector(value), staticDeps: true, eager: true);
}
