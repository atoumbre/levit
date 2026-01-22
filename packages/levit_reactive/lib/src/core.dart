import 'dart:async';

import 'package:meta/meta.dart';

import 'middlewares.dart';

@internal
class LevitStateCore {
  /// Whether to capture stack traces on state changes (expensive).
  static bool captureStackTrace = false;

  /// The active observer capturing dependencies.
  static LevitReactiveObserver? proxy;

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
    _fastPath = _asyncZoneDepth == 0 && _batchDepth == 0 && !_isPropagating;
    // print('UpdateFastPath: $_fastPath (Depth: $_batchDepth, Async: $_asyncZoneDepth, Prop: $_isPropagating)');
  }

  static void _flushGlobalBatch() {
    if (_batchedNotifiers.isEmpty) return;

    _batchDepth++;
    _updateFastPath();
    try {
      // Topological sort: Process sources (depth 0) before derived values
      // This prevents cascading re-notifications when a source changes
      // before its dependents have been notified.
      if (_batchedNotifiers.length > 1) {
        _batchedNotifiers
            .sort((a, b) => a._graphDepth.compareTo(b._graphDepth));
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

  @internal
  static void enterAsyncScope() {
    _asyncZoneDepth++;
    _updateFastPath();
  }

  @internal
  static void exitAsyncScope() {
    _asyncZoneDepth--;
    _updateFastPath();
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
        LevitStateMiddlewareChain.applyOnBatch(coreExecution, batchChange);
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
      enterAsyncScope();
      final batchSet = Set<LevitReactiveNotifier>.identity();
      try {
        return await runZoned(
          () => callback(),
          zoneValues: {_batchZoneKey: batchSet},
        );
      } finally {
        exitAsyncScope();
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
      enterAsyncScope();

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
        exitAsyncScope();
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
        LevitStateMiddlewareChain.applyOnBatch(coreExecution, batchChange);
    return await (wrapped() as Future<dynamic>);
  }
}

/// Common interface for all reactive types.
///
/// Unifies [Lx], [LxFuture], and [LxStream] so they can be used interchangeably
/// with utilities like [watch].
///
/// This interface ensures that any reactive source can be observed, streamed,
/// and listened to in a consistent manner.
abstract interface class LxReactive<T> {
  /// The current value.
  ///
  /// Reading this registers the variable with the active [LevitReactiveObserver].
  T get value;

  /// Unique identifier for this reactive object.
  int get id;

  /// A stream of value changes.
  Stream<T> get stream;

  /// Adds a listener for value changes.
  ///
  /// [listener] will be invoked whenever [value] updates.
  void addListener(void Function() listener);

  /// Removes a listener.
  ///
  /// Removes [listener] from the reactive object.
  ///
  /// [listener] will no longer be invoked on updates.
  void removeListener(void Function() listener);

  /// Closes the reactive object and releases resources.
  ///
  /// Should be called when the object is no longer needed to prevent memory leaks.
  void close();

  /// The debug name of this reactive object.
  String? get name;
  set name(String? value);

  /// The ID of the controller that owns this reactive object.
  String? get ownerId;
  set ownerId(String? value);
}

/// An observer that tracks reactive dependencies during execution.
///
/// Implemented by [LWatch] and computed values to automatically detect
/// which [Lx] variables are accessed.
///
/// This mechanism allows Levit to implement "Observation by Access," where
/// components simply use values and the framework handles subscriptions.
abstract class LevitReactiveObserver {
  /// Registers a [stream] dependency.
  void addStream<T>(Stream<T> stream);

  /// Registers a [notifier] dependency.
  void addNotifier(LevitReactiveNotifier notifier);

  /// Registers the reactive source itself (optional, for DevTools).
  ///
  /// Default implementation does nothing. Override to track reactive sources
  /// for dependency graph visualization.
  void addReactive(LxReactive reactive) {}
}

/// A specialized notifier for synchronous reactive updates.
///
/// Used internally to propagate changes without [StreamController] overhead.
/// It implements a propagation queue to handle complex dependency chains efficiently.
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

  /// Depth in dependency graph (0 = source, higher = derived).
  /// Used for topological ordering during propagation.
  int _graphDepth = 0;

  /// Get the depth of this notifier in the dependency graph.
  int get graphDepth => _graphDepth;

  /// Set the depth (internal use only by computed values).
  @internal
  set graphDepth(int value) => _graphDepth = value;

  LevitReactiveNotifier();

  /// Adds a listener.
  void addListener(void Function() listener) {
    if (_disposed) return;

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
    // IMPORTANT: Only use if we haven't migrated to _setListeners
    if (_singleListener != null &&
        _setListeners == null &&
        LevitStateCore._fastPath) {
      _singleListener!();
      return;
    }

    // 0. Handle Async Batching
    if (LevitStateCore._asyncZoneDepth > 0) {
      final asyncBatch = Zone.current[LevitStateCore._batchZoneKey];
      if (asyncBatch is Set<LevitReactiveNotifier>) {
        asyncBatch.add(this);
        return;
      }
    }

    // 1. Handle Sync Batching
    if (LevitStateCore.isBatching) {
      if (!_isPendingSyncBatch) {
        _isPendingSyncBatch = true;
        LevitStateCore._batchedNotifiers.add(this);
      }
      return;
    }

    // 2. Handle Iterative Propagation (Queueing) with deduplication
    // This is critical for diamond dependencies: when A->B and A->C both
    // notify D, we should only process D once.
    if (LevitStateCore._isPropagating) {
      if (!_isPendingPropagate) {
        _isPendingPropagate = true;
        LevitStateCore._propagationQueue.add(this);
      }
      return;
    }

    // 3. Start Propagation Cycle
    LevitStateCore._isPropagating = true;
    LevitStateCore._updateFastPath();
    try {
      _notifyListeners();

      if (LevitStateCore._propagationQueue.isNotEmpty) {
        var i = 0;
        while (i < LevitStateCore._propagationQueue.length) {
          final notifier = LevitStateCore._propagationQueue[i++];
          notifier._isPendingPropagate = false; // Clear before processing
          notifier._notifyListeners();
        }
      }
    } finally {
      LevitStateCore._isPropagating = false;
      LevitStateCore._updateFastPath();
      if (LevitStateCore._propagationQueue.isNotEmpty) {
        // Clear flags for any remaining items (safety)
        for (final n in LevitStateCore._propagationQueue) {
          n._isPendingPropagate = false;
        }
        LevitStateCore._propagationQueue.clear();
      }
    }
  }

  void _notifyListeners() {
    if (_singleListener != null) {
      _singleListener!();
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
    for (var i = 0; i < length; i++) {
      if (_disposed) break;
      snapshot[i]();
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
}

/// A reactive wrapper for a value of type [T].
///
/// [LxBase] is the core primitive of Levit's reactive system. It notifies
/// listeners whenever its value changes.
///
/// It supports:
/// *   **Observation**: Automatically tracked by [LevitReactiveObserver].
/// *   **Stream Binding**: Can bind to external [Stream]s via [bind].
/// *   **Middleware**: Supports interceptors for logging and state history.
///
/// ## Usage
/// ```dart
/// final count = LxInt(0);
/// // or
/// final count = 0.lx;
///
/// count.value++; // Notifies observers
/// ```
abstract class LxBase<T> extends LevitReactiveNotifier
    implements LxReactive<T> {
  static int _nextId = 0;

  @override
  final int id = _nextId++;

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

  @override
  String? name;

  /// Creates a reactive wrapper around [initial].
  LxBase(T initial, {this.onListen, this.onCancel, this.name})
      : _value = initial {
    if (LevitReactiveMiddleware.hasInitMiddlewares) {
      LevitStateMiddlewareChain.applyOnInit(this);
    }
  }

  @protected
  void protectedOnActive() {
    onListen?.call();
  }

  @protected
  void protectedOnInactive() {
    onCancel?.call();
  }

  void _checkActive() {
    final shouldBeActive = hasListener;
    if (shouldBeActive && !_isActive) {
      _isActive = true;
      protectedOnActive();
    } else if (!shouldBeActive && _isActive) {
      _isActive = false;
      protectedOnInactive();
    }
  }

  @override
  T get value {
    if (LevitStateCore.proxy != null) {
      _reportRead(LevitStateCore.proxy!);
    } else if (LevitStateCore._asyncZoneDepth > 0) {
      final zoneTracker =
          Zone.current[LevitStateCore.asyncComputedTrackerZoneKey];
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
  @protected
  void notifyListenersOnly() {
    super.notify();
  }

  void _reportRead(LevitReactiveObserver observer) {
    observer.addNotifier(this);
    observer.addReactive(this); // For DevTools dependency graph
    if (_controller != null || _boundStream != null) {
      observer.addStream(stream);
    }
  }

  /// Internal setter for subclasses (Computed, etc.)
  @protected
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
      stackTrace: LevitStateCore.captureStackTrace ? StackTrace.current : null,
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
      if (LevitStateCore.isBatching) {
        LevitStateCore._recordBatchEntry(this, change);
      }
    }

    final wrapped =
        LevitStateMiddlewareChain.applyOnSet<T>(performSet, this, change);
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
  @protected
  bool get hasStreamListener {
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

  @override
  void close() {
    if (LevitReactiveMiddleware.bypassMiddleware ||
        !LevitReactiveMiddleware.hasDisposeMiddlewares) {
      unbind();
      _controller?.close();
      super.dispose();
      _checkActive();
    } else {
      final wrapped = LevitStateMiddlewareChain.applyOnDispose(() {
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
      stackTrace: LevitStateCore.captureStackTrace ? StackTrace.current : null,
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
      if (LevitStateCore.isBatching) {
        LevitStateCore._recordBatchEntry(this, change);
      }
    }

    final wrapped =
        LevitStateMiddlewareChain.applyOnSet<T>(performRefresh, this, change);
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
