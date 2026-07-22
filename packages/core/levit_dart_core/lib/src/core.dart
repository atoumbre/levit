part of '../levit_dart_core.dart';

/// The central entry point for the Levit framework.
///
/// [Levit] unifies the capabilities of `levit_scope` (Dependency Injection)
/// and `levit_reactive` (Reactivity) into a single, cohesive API. It manages
/// controller lifecycles, configuration, and global middleware.
///
/// Use [put] to register dependencies and [find] to retrieve them.
class Levit {
  // ------------------------------------------------------------
  //    Reactive API accessors
  // ------------------------------------------------------------

  /// Whether to capture stack traces on state changes.
  ///
  /// Enabling this incurs a significant performance penalty.
  /// Use only for debugging.
  static bool get captureStackTrace => Lx.captureStackTrace;

  static set captureStackTrace(bool value) {
    Lx.captureStackTrace = value;
  }

  /// Whether to monitor performance metrics for [LxWorker].
  static bool get enableWatchMonitoring => Lx.enableWatchMonitoring;

  static set enableWatchMonitoring(bool value) {
    Lx.enableWatchMonitoring = value;
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications are deferred until the batch completes, ensuring that
  /// observers are only notified once even if multiple values change.
  ///
  /// // Example usage:
  /// ```dart
  /// Levit.batch(() {
  ///   firstName.value = 'Jane';
  ///   lastName.value = 'Doe';
  /// });
  /// ```
  ///
  /// Returns the value returned by [callback].
  ///
  /// Throws any exception thrown by [callback].
  static R batch<R>(R Function() callback) {
    return Lx.batch(callback);
  }

  /// Executes an asynchronous [callback] in a batch.
  ///
  /// The batching context is maintained across await points.
  ///
  /// Returns the value returned by [callback].
  ///
  /// Throws any exception thrown by [callback].
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return Lx.batchAsync(callback);
  }

  /// Bypasses all state middlewares for the duration of [action].
  ///
  /// Throws any exception thrown by [action].
  static void runWithoutStateMiddleware(void Function() action) {
    Lx.runWithoutMiddleware(action);
  }

  /// Clears all registered state middlewares.
  static void clearStateMiddlewares() {
    Lx.clearMiddlewares();
  }

  /// Checks if [middleware] is currently registered.
  static bool containsStateMiddleware(LevitReactiveMiddleware middleware) {
    return Lx.containsMiddleware(middleware);
  }

  /// Executes [fn] within a specific listener context.
  ///
  /// Used internally to attribute subscriptions to specific widgets or controllers.
  ///
  /// Returns the value returned by [fn].
  ///
  /// Throws any exception thrown by [fn].
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return Lx.runWithContext(context, fn);
  }

  // ------------------------------------------------------------
  //    Levit API accessors
  // ------------------------------------------------------------

  /// Instantiates and registers a dependency.
  ///
  /// The [builder] is executed immediately.
  /// If [permanent] is true, the instance survives a *non-forced* [reset].
  /// Scope dispose always resets with `force: true`, so permanents do not leak
  /// across disposed scopes. Prefer permanent on root / long-lived scopes.
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Levit.put(() => AuthService());
  /// ```
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return Ls.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency builder.
  ///
  /// The [builder] runs only when the dependency is first requested.
  ///
  /// *   If [isFactory] is true, [builder] runs on every request.
  /// *   If [permanent] is true, registration survives a *non-forced* [reset].
  ///     Scope dispose always force-clears permanents.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    Ls.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous lazy dependency builder.
  ///
  /// Retrieve the instance using [findAsync].
  /// If [permanent] is true, registration survives a *non-forced* [reset].
  /// Scope dispose always force-clears permanents.
  static Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return Ls.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Finds a registered instance of type [S].
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Levit.find<AuthService>();
  /// ```
  static S find<S>({String? tag}) {
    return Ls.find<S>(tag: tag);
  }

  /// Finds an instance of type [S], or returns `null` if missing.
  static S? findOrNull<S>({String? tag}) {
    return Ls.findOrNull<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S].
  ///
  /// Use for dependencies registered via [lazyPutAsync].
  static Future<S> findAsync<S>({String? tag}) async {
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S], or returning `null`.
  static Future<S?> findOrNullAsync<S>({String? tag}) async {
    return Ls.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered.
  static bool isRegistered<S>({String? tag}) {
    return Ls.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] is already instantiated (not just pending lazy init).
  static bool isInstantiated<S>({String? tag}) {
    return Ls.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  /// If [force] is true, deletes even if the dependency was marked as `permanent`.
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({String? tag, bool force = false}) {
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// If [force] is true, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    Ls.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// Child scopes can override parent dependencies and provide their own
  /// isolated lifecycle. The [name] is used for profiling and logs.
  static LevitScope createScope(String name) {
    return Ls.createScope(name);
  }

  /// Runs [callback] in a fresh child scope and disposes it automatically.
  ///
  /// This helper is useful in tests and short-lived workflows where manual
  /// `createScope`/`dispose` plumbing adds noise.
  ///
  /// Uses [name] for scope diagnostics and middleware metadata.
  /// If [parentScope] is provided, the child scope is created under that scope;
  /// otherwise it is created under the current scope.
  ///
  /// Returns the value returned by [callback].
  ///
  /// Throws any exception thrown by [callback] after disposing the child scope.
  static FutureOr<R> runInScope<R>(
    FutureOr<R> Function() callback, {
    String name = 'scoped_run',
    LevitScope? parentScope,
  }) {
    final scope = (parentScope ?? Ls.currentScope).createScope(name);
    try {
      final result = scope.run(callback);
      if (result is Future<R>) {
        return result.whenComplete(scope.dispose);
      }
      scope.dispose();
      return result;
    } catch (_) {
      scope.dispose();
      rethrow;
    }
  }

  // -------------------------------------------------------------
  //    Middleware accessors
  // -------------------------------------------------------------

  /// The total number of dependencies registered in the current active scope.
  static int get registeredCount => Ls.registeredCount;

  /// A list of all registration keys (type + tag) in the current active scope.
  static List<String> get registeredKeys => Ls.registeredKeys;

  /// Adds a global middleware for receiving dependency injection events.
  static void addDependencyMiddleware(
    LevitScopeMiddleware middleware, {
    Object? token,
  }) {
    Ls.addMiddleware(middleware, token: token);
  }

  /// Removes a DI middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.removeMiddleware(middleware);
  }

  /// Removes a DI middleware by [token].
  static bool removeDependencyMiddlewareByToken(Object token) {
    return Ls.removeMiddlewareByToken(token);
  }

  /// Adds a middleware to the list of active middlewares.
  static void addStateMiddleware(
    LevitReactiveMiddleware middleware, {
    Object? token,
  }) {
    Lx.addMiddleware(middleware, token: token);
  }

  /// Removes a middleware from the list of active middlewares.
  static void removeStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.removeMiddleware(middleware);
  }

  /// Removes a state middleware by [token].
  static bool removeStateMiddlewareByToken(Object token) {
    return Lx.removeMiddlewareByToken(token);
  }

  // -------------------------------------------------------------
  //   Auto-Linking
  // -------------------------------------------------------------

  static LevitReactiveMiddleware? _autoLinkMiddleware;
  static LevitScopeMiddleware? _autoDisposeMiddleware;

  /// Enables automatic linking of reactive state to controller lifecycles.
  ///
  /// When enabled, [LxReactive] objects created while instantiating or
  /// initializing a [LevitController] are automatically registered via
  /// [LevitController.autoDispose] and disposed when the controller is closed.
  static void enableAutoLinking() {
    if (_autoLinkMiddleware != null) return; // Already enabled

    _autoLinkMiddleware = _AutoLinkMiddleware();
    _autoDisposeMiddleware = _AutoDisposeMiddleware();

    Lx.addMiddleware(_autoLinkMiddleware!);
    LevitScope.addMiddleware(_autoDisposeMiddleware!);
  }

  /// Disables automatic linking.
  static void disableAutoLinking() {
    if (_autoLinkMiddleware == null) return; // Already disabled

    Lx.removeMiddleware(_autoLinkMiddleware!);
    LevitScope.removeMiddleware(_autoDisposeMiddleware!);

    _autoLinkMiddleware = null;
    _autoDisposeMiddleware = null;
  }

// -------------------------------------------------------------
//    Internal utils
// -------------------------------------------------------------

  /// Internal utility that detects and executes the appropriate cleanup method for an [item].
  static void _levitDisposeItem(dynamic item) {
    if (item == null) return;
    if (_disposeKnownItem(item)) return;
    if (_cancelKnownItem(item)) return;
    if (_tryDynamicCleanup(item, _CleanupOperation.cancel)) return;
    if (_tryDynamicCleanup(item, _CleanupOperation.dispose)) return;
    if (_closeKnownItem(item)) return;
    if (_tryDynamicCleanup(item, _CleanupOperation.close)) return;
    _runCleanupCallback(item);
  }

  static bool _disposeKnownItem(Object item) {
    if (item is LxReactive) {
      item.close();
      return true;
    }

    if (item is LevitScopeDisposable) {
      item.onClose();
      return true;
    }

    if (item is LevitDisposable) {
      item.dispose();
      return true;
    }

    return false;
  }

  static bool _cancelKnownItem(Object item) {
    if (item is StreamSubscription) {
      item.cancel();
      return true;
    }

    if (item is Timer) {
      item.cancel();
      return true;
    }

    return false;
  }

  static bool _closeKnownItem(Object item) {
    if (item is Sink) {
      item.close();
      return true;
    }
    return false;
  }

  static bool _tryDynamicCleanup(Object item, _CleanupOperation operation) {
    try {
      switch (operation) {
        case _CleanupOperation.cancel:
          (item as dynamic).cancel();
          break;
        case _CleanupOperation.dispose:
          (item as dynamic).dispose();
          break;
        case _CleanupOperation.close:
          (item as dynamic).close();
          break;
      }
      return true;
    } on NoSuchMethodError {
      return false;
    } on Exception catch (e, stackTrace) {
      _logCleanupError(
        operation.label,
        item,
        e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static void _runCleanupCallback(Object item) {
    if (item is! void Function()) return;

    try {
      item();
    } on Exception catch (e, stackTrace) {
      _logCleanupError(
        'executing dispose callback',
        item,
        e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _logCleanupError(
    String operation,
    Object item,
    Exception error, {
    StackTrace? stackTrace,
  }) {
    dev.log(
      'Levit: Error $operation ${item.runtimeType}',
      error: error,
      stackTrace: stackTrace,
      name: 'levit_dart',
    );
  }
}

enum _CleanupOperation {
  cancel('cancelling'),
  dispose('disposing'),
  close('closing');

  const _CleanupOperation(this.label);

  final String label;
}

/// Fluent extensions for naming and configuring reactive objects.
extension LxNamingExtension<R extends LxReactive> on R {
  /// assigns a debug [name] to this reactive object.
  R named(String name) {
    this.name = name;
    return this;
  }

  /// Links this reactive object to an owner ID.
  R register(String ownerId) {
    this.ownerId = ownerId;
    return this;
  }

  /// Marks this object as containing sensitive data (redacted in logs).
  R sensitive() {
    this.isSensitive = true;
    return this;
  }
}

/// Interface for objects that require explicit disposal logic.
///
/// Implement this interface for custom classes managed by [Levit] to ensure
/// their resources (streams, connections) are released when the scope closes.
abstract class LevitDisposable {
  /// Releases resources held by this object.
  void dispose();
}
