part of 'dart_core_library.dart';

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
  /// Notifications are batched across awaits only in this execution context.
  /// Concurrent batches flush independently, and nested batches merge at the
  /// outer open boundary. Errors flush pending notifications before propagating.
  /// Values remain shared: outside writes notify immediately, including writes
  /// to the same reactive. Batching provides neither isolation nor rollback.
  ///
  /// Returns the value returned by [callback].
  ///
  /// Throws any exception thrown by [callback].
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return Lx.batchAsync(callback);
  }

  /// Reads reactive state without subscribing an enclosing consumer.
  static R untracked<R>(R Function() read) {
    return Lx.untracked(read);
  }

  /// Whether the current execution context has an open reactive batch.
  static bool get isBatching => Lx.isBatching;

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

  /// Checks whether a state middleware [token] is currently registered.
  static bool containsStateMiddlewareToken(Object token) {
    return Lx.containsMiddlewareToken(token);
  }

  // ------------------------------------------------------------
  //    Levit API accessors
  // ------------------------------------------------------------

  /// The currently active [LevitScope] for this execution zone, or the root scope.
  static LevitScope get currentScope => Ls.currentScope;

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
  static S put<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    return Ls.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency builder.
  ///
  /// The [builder] runs only when the dependency is first requested.
  ///
  /// *   If [isFactory] is true, [builder] runs on every request.
  /// *   If [permanent] is true, registration survives a *non-forced* [reset].
  ///     Scope dispose always force-clears permanents.
  static void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    Ls.lazyPut<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  /// Registers an asynchronous lazy dependency builder.
  ///
  /// Retrieve the instance using [findAsync].
  /// If [permanent] is true, registration survives a *non-forced* [reset].
  /// Scope dispose always force-clears permanents.
  static Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    return Ls.lazyPutAsync<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  /// Binds [Alias] to an existing local singleton [Concrete].
  static void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  }) {
    Ls.bindExisting<Alias, Concrete>(sourceTag: sourceTag, tag: tag);
  }

  /// Finds a registered instance of type [S].
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Levit.find<AuthService>();
  /// ```
  static S find<S>({Object? tag}) {
    return Ls.find<S>(tag: tag);
  }

  /// Finds an instance of type [S], or returns `null` if missing.
  static S? findOrNull<S>({Object? tag}) {
    return Ls.findOrNull<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S].
  ///
  /// Use for dependencies registered via [lazyPutAsync].
  static Future<S> findAsync<S>({Object? tag}) async {
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S], or returning `null`.
  static Future<S?> findOrNullAsync<S>({Object? tag}) async {
    return Ls.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered.
  static bool isRegistered<S>({Object? tag}) {
    return Ls.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] is already instantiated (not just pending lazy init).
  static bool isInstantiated<S>({Object? tag}) {
    return Ls.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  /// If [force] is true, deletes even if the dependency was marked as `permanent`.
  /// Returns `true` if a registration was found and removed.
  static Future<bool> delete<S>({Object? tag, bool force = false}) {
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
  static LevitScope createScope(String name, {bool ownedByParent = true}) {
    return Ls.createScope(name, ownedByParent: ownedByParent);
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
  /// through [LevitResourceOwner.own] and disposed with that owner.
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

  static bool _canDisposeItem(Object item) =>
      item is LxReactive ||
      item is LxResource ||
      item is LevitScopeDisposable ||
      item is LevitDisposable ||
      item is StreamSubscription ||
      item is Timer ||
      item is Sink ||
      item is FutureOr<void> Function();

  /// Runs a supported typed cleanup operation. Other resources need an adapter.
  static Future<void> _levitDisposeItem(Object? item) async {
    if (item == null) return;
    if (item is LxReactive) return item.close();
    if (item is LxResource) return item.close();
    if (item is LevitScopeDisposable) return item.onClose();
    if (item is LevitDisposable) return item.dispose();
    if (item is StreamSubscription) return item.cancel();
    if (item is Timer) {
      item.cancel();
      return;
    }
    if (item is StreamSink) return item.close().then<void>((_) {});
    if (item is Sink) {
      item.close();
      return;
    }
    // own() validates supported resources before admission. After the resource
    // adapters above, the only remaining supported type is a cleanup callback.
    return (item as FutureOr<void> Function())();
  }
}

/// Fluent extensions for naming and configuring reactive objects.
extension LxNamingExtension<R extends LxReactive> on R {
  /// assigns a debug [name] to this reactive object.
  R named(String name) {
    this.name = name;
    return this;
  }

  /// Associates this reactive object with an owner ID for diagnostics.
  R ownedBy(String ownerId) {
    this.ownerId = ownerId;
    return this;
  }

  /// Marks this object as containing sensitive data (redacted in logs).
  R sensitive() {
    this.isSensitive = true;
    return this;
  }
}
