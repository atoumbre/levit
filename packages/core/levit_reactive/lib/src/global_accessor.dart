part of 'reactive_library.dart';

/// The low-level global entry point for the Levit reactive engine.
///
/// [Lx] provides static access to core functionality, including configuration,
/// untracked reads, middleware registration, and batching.
///
/// High-level kits (`levit`, `levit_dart`, and `levit_flutter`) intentionally
/// hide [Lx] in favor of the unified `Levit` facade (`Levit.batch`,
/// `Levit.batchAsync`, `Levit.untracked`, `Levit.isBatching`).
///
/// {@category Reactive State}
class Lx {
  /// Reads reactive state without subscribing an enclosing consumer.
  static R untracked<R>(R Function() read) {
    final previous = _LevitReactiveCore.proxy;
    if (previous == null && _LevitReactiveCore._asyncTrackerDepth == 0) {
      return read();
    }
    _LevitReactiveCore.proxy = null;
    try {
      if (_LevitReactiveCore._asyncTrackerDepth != 0) {
        return runZoned(
          read,
          zoneValues: {_LevitReactiveCore.asyncComputedTrackerZoneKey: null},
        );
      }
      return read();
    } finally {
      _LevitReactiveCore.proxy = previous;
    }
  }

  /// Whether to capture stack traces on state changes (performance intensive).
  static bool get captureStackTrace => _LevitReactiveCore.captureStackTrace;

  /// Sets whether stack traces are captured on state changes.
  static set captureStackTrace(bool value) {
    _LevitReactiveCore.captureStackTrace = value;
  }

  static bool _enableWatchMonitoring = false;

  /// Global flag to enable or disable performance monitoring for all [LxWorker] instances.
  ///
  /// When `true`, watchers track execution counts and durations.
  static bool get enableWatchMonitoring => _enableWatchMonitoring;

  /// Sets whether performance monitoring is enabled globally for [LxWorker]
  /// instances.
  static set enableWatchMonitoring(bool value) {
    _enableWatchMonitoring = value;
  }

  /// Registers a new [LevitReactiveMiddleware] to intercept or observe state changes.
  ///
  /// If [token] is provided, registration is unique for that token.
  static LevitReactiveMiddleware addMiddleware(
    LevitReactiveMiddleware middleware, {
    Object? token,
  }) {
    return LevitReactiveMiddleware.add(middleware, token: token);
  }

  /// Unregisters a previously added middleware.
  static bool removeMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.remove(middleware);
  }

  /// Unregisters a middleware by [token].
  static bool removeMiddlewareByToken(Object token) {
    return LevitReactiveMiddleware.removeByToken(token);
  }

  /// Removes all active middlewares.
  static void clearMiddlewares() {
    LevitReactiveMiddleware.clear();
  }

  /// Checks if a particular middleware is currently registered.
  static bool containsMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.contains(middleware);
  }

  /// Checks whether a middleware token is currently registered.
  static bool containsMiddlewareToken(Object token) {
    return LevitReactiveMiddleware.containsToken(token);
  }

  /// Executes [action] while temporarily bypassing all registered middlewares.
  static void runWithoutMiddleware(void Function() action) {
    LevitReactiveMiddleware.runWithoutMiddleware(action);
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications for all variables mutated inside the batch are deferred
  /// until the outermost batch completes (or throws), ensuring at most one
  /// notification per variable. Nested calls coalesce into the enclosing batch.
  /// Do not pass an `async` callback here; use [batchAsync] for async work.
  static R batch<R>(R Function() callback) {
    return _LevitReactiveCore.batch(callback);
  }

  /// Executes asynchronous [callback] in a batch.
  ///
  /// Notifications are collected in the current execution context across awaits.
  /// Concurrent outer batches flush independently; nested batches merge into an
  /// enclosing open batch. Errors flush changes and close the context.
  /// Values remain shared: outside writes notify immediately, even to a source
  /// touched by a pending batch. This provides no isolation or rollback.
  /// Work escaping the callback uses an enclosing open batch or normal delivery.
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return _LevitReactiveCore.batchAsync(callback);
  }

  /// Returns `true` if the current execution context has an open batch.
  static bool get isBatching => _LevitReactiveCore.isBatching;
}

/// Low-level runtime hooks exposed via `package:levit_reactive/spi.dart`.
///
/// {@category SPI}
abstract final class LxSpi {
  static List<(LxReactive, void Function())>? _construction;

  /// Runs a synchronous factory whose returned object has an explicit owner.
  /// Dependency capture still receives independent reactive allocations.
  static R createOwned<R>(R Function() create) {
    final parent = _construction;
    final captured = <(LxReactive, void Function())>[];
    _construction = captured;
    Object? result;
    try {
      final created = create();
      result = created;
      return created;
    } finally {
      _construction = parent;
      for (final item in captured) {
        if (!identical(item.$1, result)) {
          if (parent == null) {
            item.$2();
          } else {
            parent.add(item);
          }
        }
      }
    }
  }

  /// Whether a synchronous [createOwned] construction frame is currently active.
  static bool get isConstructingOwned => _construction != null;

  /// Framework hook for automatic ownership capture during [createOwned].
  static bool deferAutoLink(LxReactive reactive, void Function() capture) {
    final frame = _construction;
    if (frame == null) return false;
    frame.add((reactive, capture));
    return true;
  }

  /// The active observer capturing dependencies.
  static LevitReactiveObserver? get proxy => _LevitReactiveCore.proxy;

  /// Sets the active observer.
  static set proxy(LevitReactiveObserver? value) {
    _LevitReactiveCore.proxy = value;
  }

  /// Whether any registered reactive middleware implements `onInit`.
  static bool get hasInitMiddlewares =>
      LevitReactiveMiddleware._hasInitMiddlewares;

  /// Whether any registered reactive middleware tracks listener activity.
  static bool get hasListenerMiddlewares =>
      LevitReactiveMiddleware._hasListenerMiddlewares;

  /// Runs [fn] with [context] installed as the active [listenerContext].
  ///
  /// [LevitReactiveMiddleware.startedListening] and
  /// [LevitReactiveMiddleware.stoppedListening] receive [context] for listener
  /// changes triggered synchronously inside [fn]. The previous context is
  /// restored when [fn] completes or throws.
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return _LevitReactiveCore.runWithContext(context, fn);
  }

  /// Returns the current active listener context, if any.
  static LxListenerContext? get listenerContext =>
      _LevitReactiveCore.listenerContext;

  /// Executes [fn] while associating any created reactive variables with [ownerId].
  static T runWithOwner<T>(String ownerId, T Function() fn) {
    // A producer factory can resolve another owner. Let the nested owner
    // capture its own allocations before its construction completes.
    final outerConstruction = _construction;
    _construction = null;
    try {
      return _LevitReactiveCore.runWithContext(
        LxListenerContext(type: 'Owner', id: 0, data: {'ownerId': ownerId}),
        fn,
      );
    } finally {
      _construction = outerConstruction;
    }
  }

  /// Enters an asynchronous tracking scope.
  static void enterAsyncScope() {
    _LevitReactiveCore._enterAsyncScope();
  }

  /// Exits an asynchronous tracking scope.
  static void exitAsyncScope() {
    _LevitReactiveCore._exitAsyncScope();
  }

  /// Zone key for identifying the active async computed tracker.
  static Object get asyncComputedTrackerZoneKey =>
      _LevitReactiveCore.asyncComputedTrackerZoneKey;

  /// Overrides the dependency graph depth on [notifier] for internal testing.
  static void setGraphDepth(LevitReactiveNotifier notifier, int value) {
    notifier._graphDepth = value;
  }

  /// Closes [reactive] synchronously when no stream, binding, or dispose
  /// middleware requires asynchronous teardown; otherwise returns its [Future].
  static FutureOr<void> closeSyncOrAsync(LxReactive reactive) {
    if (reactive is LxBase && reactive is! _LxAsyncLifecycle) {
      return reactive._closeSyncOrAsync();
    }
    return reactive.close();
  }

  /// Whether [variable] has no pending binding cancellations or failures.
  static bool isDrainedSync(LxVar<dynamic> variable) => variable._isDrainedSync;

  /// Whether [resource] is currently executing in the active reactive context.
  static bool isExecuting(Object resource) {
    return LxExecutionContext._isExecuting(resource);
  }
}
