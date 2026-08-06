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

  /// Binds [Alias] to an existing local singleton [Concrete].
  static void bindExisting<Alias, Concrete extends Alias>({
    String? sourceTag,
    String? tag,
  }) {
    Ls.bindExisting<Alias, Concrete>(
      sourceTag: sourceTag,
      tag: tag,
    );
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
  static Future<bool> delete<S>({String? tag, bool force = false}) {
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// If [force] is true, also disposes of permanent dependencies.
  static Future<void> reset({bool force = false}) {
    return Ls.reset(force: force);
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
  static Future<R> runInScope<R>(
    FutureOr<R> Function() callback, {
    String name = 'scoped_run',
    LevitScope? parentScope,
  }) async {
    final scope = (parentScope ?? Ls.currentScope).createScope(name);
    try {
      return await scope.run(callback);
    } finally {
      await scope.dispose();
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

  /// Enables automatic linking of reactive state to resource-owner lifecycles.
  ///
  /// When enabled, [LxReactive] objects created while instantiating or
  /// initializing a returned [LevitResourceOwner] are automatically registered
  /// through [LevitResourceOwner.autoDispose] and disposed with that owner.
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
  static dynamic _levitDisposeItem(dynamic item) {
    if (item == null) return;
    if (item is LxReactive) {
      item.close();
      return;
    }

    if (item is LevitScopeDisposable) {
      return item.onClose();
    }

    if (item is LevitDisposable) {
      return item.dispose();
    }
    if (item is StreamSubscription) {
      return item.cancel();
    }

    if (item is Timer) {
      item.cancel();
      return;
    }
    if (item is Sink) {
      item.close();
      return;
    }

    for (final operation in _CleanupOperation.values) {
      final result = _tryDynamicCleanup(item, operation);
      if (!identical(result, _cleanupNotFound)) {
        return result is Future ? result.then<void>((_) {}) : null;
      }
    }

    if (item is FutureOr<void> Function()) {
      return item();
    }
  }

  static const Object _cleanupNotFound = Object();

  static Object? _tryDynamicCleanup(Object item, _CleanupOperation operation) {
    try {
      dynamic result;
      switch (operation) {
        case _CleanupOperation.cancel:
          result = (item as dynamic).cancel();
          break;
        case _CleanupOperation.dispose:
          result = (item as dynamic).dispose();
          break;
        case _CleanupOperation.close:
          result = (item as dynamic).close();
          break;
      }
      return result;
    } on NoSuchMethodError {
      return _cleanupNotFound;
    }
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
