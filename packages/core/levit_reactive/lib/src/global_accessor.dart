part of '../levit_reactive.dart';

/// The global entry point for the Levit reactive engine.
///
/// [Lx] provides static access to core functionality, including configuration,
/// dependency tracking, and batching.
class Lx {
  /// The active observer capturing dependencies.
  static LevitReactiveObserver? get proxy => _LevitReactiveCore.proxy;

  /// Sets the active observer. Used by [LWatch] and [LxComputed].
  static set proxy(LevitReactiveObserver? value) {
    _LevitReactiveCore.proxy = value;
  }

  /// Whether to capture stack traces on state changes (performance intensive).
  static bool get captureStackTrace => _LevitReactiveCore.captureStackTrace;

  static set captureStackTrace(bool value) {
    _LevitReactiveCore.captureStackTrace = value;
  }

  static bool _enableWatchMonitoring = true;

  /// Global flag to enable or disable performance monitoring for all [LxWorker] instances.
  ///
  /// When `true` (default), watchers track execution counts and durations.
  static bool get enableWatchMonitoring => _enableWatchMonitoring;

  static set enableWatchMonitoring(bool value) {
    _enableWatchMonitoring = value;
  }

  /// Registers a new [LevitReactiveMiddleware] to intercept or observe state changes.
  static LevitReactiveMiddleware addMiddleware(
      LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.add(middleware);
  }

  /// Unregisters a previously added middleware.
  static bool removeMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.remove(middleware);
  }

  /// Removes all active middlewares.
  static void clearMiddlewares() {
    LevitReactiveMiddleware.clear();
  }

  /// Checks if a particular middleware is currently registered.
  static bool containsMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.contains(middleware);
  }

  /// Executes [action] while temporarily bypassing all registered middlewares.
  static void runWithoutMiddleware(void Function() action) {
    LevitReactiveMiddleware.runWithoutMiddleware(action);
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications for all variables mutated inside the batch are deferred
  /// until the callback completes, ensuring only a single notification per variable.
  static R batch<R>(R Function() callback) {
    return _LevitReactiveCore.batch(callback);
  }

  /// Executes asynchronous [callback] in a batch.
  ///
  /// Like [batch], but maintains the batching context across asynchronous gaps.
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return _LevitReactiveCore.batchAsync(callback);
  }

  /// Returns `true` if a batching operation is currently in progress.
  static bool get isBatching => _LevitReactiveCore.isBatching;

  /// The context is passed to [LevitReactiveMiddleware.startedListening]
  /// and [LevitReactiveMiddleware.stoppedListening].
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return _LevitReactiveCore.runWithContext(context, fn);
  }

  /// Returns the current active listener context, if any.
  static LxListenerContext? get listenerContext =>
      _LevitReactiveCore.listenerContext;

  /// Executes [fn] while associating any created reactive variables with [ownerId].
  static T runWithOwner<T>(String ownerId, T Function() fn) {
    return _LevitReactiveCore.runWithContext(
        LxListenerContext(type: 'Owner', id: 0, data: {'ownerId': ownerId}),
        fn);
  }

  /// Internal: Enters an asynchronous tracking scope.
  @visibleForTesting
  static void enterAsyncScope() {
    _LevitReactiveCore._enterAsyncScope();
  }

  /// Internal: Exits an asynchronous tracking scope.
  @visibleForTesting
  static void exitAsyncScope() {
    _LevitReactiveCore._exitAsyncScope();
  }

  /// Internal: Zone key for identifying the active async computed tracker.
  @visibleForTesting
  static Object get asyncComputedTrackerZoneKey =>
      _LevitReactiveCore.asyncComputedTrackerZoneKey;
}
