part of 'dart_core_library.dart';

/// The central entry point for the Levit framework.
///
/// [Levit] unifies the capabilities of `levit_scope` (Dependency Injection)
/// and `levit_reactive` (Reactivity) into a single, cohesive API. It manages
/// controller lifecycles, configuration, reactive batching, and global
/// middleware.
///
/// Use [put] / [lazyPut] / [lazyPutAsync] to register dependencies and [find]
/// to resolve them in pure Dart. In Flutter widget trees that use `LScope`,
/// prefer `context.levit.find<T>()` over bare [Levit.find]. Call
/// [enableAutoLinking] once at startup (for example in Flutter `main()` before
/// `runApp`).
///
/// {@category Scopes & DI}
class Levit {
  // ------------------------------------------------------------
  //    Reactive API accessors
  // ------------------------------------------------------------

  /// Whether to capture stack traces on state changes.
  ///
  /// Enabling this incurs a significant performance penalty.
  /// Use only for debugging.
  static bool get captureStackTrace => Lx.captureStackTrace;

  /// Sets whether stack traces are captured on state changes.
  static set captureStackTrace(bool value) {
    Lx.captureStackTrace = value;
  }

  /// Whether to monitor performance metrics for [LxWorker].
  static bool get enableWatchMonitoring => Lx.enableWatchMonitoring;

  /// Sets whether performance metrics are collected for [LxWorker] instances.
  static set enableWatchMonitoring(bool value) {
    Lx.enableWatchMonitoring = value;
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications are deferred until the batch completes, ensuring that
  /// observers are only notified once even if multiple values change.
  ///
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
  /// If [permanent] is `true`, the instance survives a *non-forced* [reset].
  /// Scope disposal always force-clears permanent registrations so they do not
  /// leak across disposed scopes. Prefer `permanent: true` on root or
  /// long-lived scopes.
  ///
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
  /// * If [isFactory] is `true`, [builder] runs on every request and the
  ///   registering scope owns any disposable results.
  /// * If [permanent] is `true`, registration survives a *non-forced* [reset].
  ///   Scope disposal always force-clears permanent registrations.
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
  /// If [permanent] is `true`, registration survives a *non-forced* [reset].
  /// Scope disposal always force-clears permanent registrations.
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

  /// Binds [Alias] to an existing local singleton [Concrete] without creating
  /// a second ownership lifecycle.
  ///
  /// Use [sourceTag] to select a tagged [Concrete] registration and [tag] to
  /// disambiguate the alias. Deleting the alias does not dispose [Concrete].
  ///
  /// ```dart
  /// Levit.put(() => HttpUsersRepository());
  /// Levit.bindExisting<UsersRepository, HttpUsersRepository>();
  /// ```
  static void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  }) {
    Ls.bindExisting<Alias, Concrete>(sourceTag: sourceTag, tag: tag);
  }

  /// Finds a registered instance of type [S] in [currentScope].
  ///
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
  static Future<S> findAsync<S>({Object? tag}) {
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S], or returns `null`.
  static Future<S?> findOrNullAsync<S>({Object? tag}) {
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

  /// Removes the local registration for [S] and awaits disposal of any owned instances.
  ///
  /// Disposes [LevitScopeDisposable] (`onClose`), [LevitDisposable] (`dispose`),
  /// and disposable factory results owned by this registration. Removing an
  /// alias created by [bindExisting] removes only the alias without disposing
  /// the canonical instance.
  ///
  /// If [force] is `true`, deletes even if the dependency was marked as `permanent`.
  /// Always `await` deletion before replacing an instantiated registration.
  /// Returns `true` if a registration was found and removed.
  static Future<bool> delete<S>({Object? tag, bool force = false}) {
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes all non-permanent dependencies in the current scope.
  ///
  /// If [force] is `true`, also disposes permanent dependencies. Always `await`
  /// completion so asynchronous cleanup finishes deterministically.
  static Future<void> reset({bool force = false}) {
    return Ls.reset(force: force);
  }

  /// Creates a new child scope branching from [currentScope].
  ///
  /// Child scopes can override parent dependencies and provide their own
  /// isolated lifecycle. The [name] is used for profiling and logs. When
  /// [ownedByParent] is `true` (default), disposing the parent automatically
  /// disposes this child first; always `await scope.dispose()` when done.
  static LevitScope createScope(String name, {bool ownedByParent = true}) {
    return Ls.createScope(name, ownedByParent: ownedByParent);
  }

  /// Runs [callback] in a fresh child scope and awaits its disposal on exit.
  ///
  /// This helper is ideal for tests and short-lived workflows where manual
  /// `createScope`/`dispose` plumbing adds noise.
  ///
  /// Uses [name] for scope diagnostics and middleware metadata.
  /// If [parentScope] is provided, the child scope is created under that scope;
  /// otherwise it is created under [currentScope].
  ///
  /// ```dart
  /// final ping = await Levit.runInScope(() async {
  ///   Levit.put(() => ApiClient());
  ///   return await Levit.find<ApiClient>().ping();
  /// });
  /// ```
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
  ///
  /// Pass a stable [token] per concern so re-registering with the same token
  /// replaces the previous middleware in place and allows cleanup via
  /// [removeDependencyMiddlewareByToken].
  static void addDependencyMiddleware(
    LevitScopeMiddleware middleware, {
    Object? token,
  }) {
    Ls.addMiddleware(middleware, token: token);
  }

  /// Removes a previously registered DI middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.removeMiddleware(middleware);
  }

  /// Removes a DI middleware by [token]. Returns `true` if one was removed.
  static bool removeDependencyMiddlewareByToken(Object token) {
    return Ls.removeMiddlewareByToken(token);
  }

  /// Adds a global reactive state middleware.
  ///
  /// Pass a stable [token] per concern so re-registering replaces in place and
  /// cleanup can use [removeStateMiddlewareByToken].
  static void addStateMiddleware(
    LevitReactiveMiddleware middleware, {
    Object? token,
  }) {
    Lx.addMiddleware(middleware, token: token);
  }

  /// Removes a global reactive state middleware.
  static void removeStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.removeMiddleware(middleware);
  }

  /// Removes a state middleware by [token]. Returns `true` if one was removed.
  static bool removeStateMiddlewareByToken(Object token) {
    return Lx.removeMiddlewareByToken(token);
  }

  // -------------------------------------------------------------
  //   Auto-Linking
  // -------------------------------------------------------------

  static LevitReactiveMiddleware? _autoLinkMiddleware;
  static LevitScopeMiddleware? _autoDisposeMiddleware;
  static bool _autoLinkingDisabledByUser = false;

  /// Whether automatic linking of reactive state to [LevitController]
  /// lifecycles is currently enabled.
  static bool get isAutoLinkingEnabled => _autoLinkMiddleware != null;

  /// Enables automatic linking of reactive state to [LevitController]
  /// lifecycles.
  ///
  /// When enabled, [LxReactive] objects created while instantiating or
  /// initializing a [LevitController] are automatically registered through
  /// [LevitController.own] and closed when that controller closes.
  ///
  /// In Flutter apps, mounting an `LScope` or `LAsyncScope` enables
  /// auto-linking automatically unless [disableAutoLinking] was explicitly
  /// called. Calling [enableAutoLinking] in `main()` remains recommended when
  /// controllers are registered before the first `LScope` mounts, and is still
  /// required in pure Dart entry points. Monitoring (`levit_monitor`) never
  /// enables auto-linking. Non-reactive resources and reactives created
  /// outside construction or `onInit` must still be registered explicitly with
  /// `own(...)`.
  static void enableAutoLinking() {
    _autoLinkingDisabledByUser = false;
    if (_autoLinkMiddleware != null) return; // Already enabled

    _autoLinkMiddleware = _AutoLinkMiddleware();
    _autoDisposeMiddleware = _AutoDisposeMiddleware();

    Lx.addMiddleware(_autoLinkMiddleware!);
    LevitScope.addMiddleware(_autoDisposeMiddleware!);
  }

  /// Disables automatic linking and opts out of automatic Flutter activation.
  static void disableAutoLinking() {
    _autoLinkingDisabledByUser = true;
    if (_autoLinkMiddleware == null) return; // Already disabled

    Lx.removeMiddleware(_autoLinkMiddleware!);
    LevitScope.removeMiddleware(_autoDisposeMiddleware!);

    _autoLinkMiddleware = null;
    _autoDisposeMiddleware = null;
  }

  // -------------------------------------------------------------
  //    Internal utils
  // -------------------------------------------------------------

  static bool _canDisposeItem(Object item) {
    if (item is LxReactive ||
        item is LevitScopeDisposable ||
        item is LevitDisposable ||
        item is StreamSubscription ||
        item is Timer ||
        item is Sink ||
        item is FutureOr<void> Function()) {
      return true;
    }
    for (final adapter in LevitResourceDisposerSpi._adapters) {
      if (adapter.matches(item)) return true;
    }
    return false;
  }

  /// Runs a supported typed cleanup operation. Other resources need an adapter.
  static FutureOr<void> _levitDisposeItem(Object? item) {
    if (item == null) return null;
    if (item is LxReactive) return LxSpi.closeSyncOrAsync(item);
    if (item is LevitScopeDisposable) return item.onClose();
    if (item is LevitDisposable) return item.dispose();
    if (item is StreamSubscription) return item.cancel();
    if (item is Timer) {
      item.cancel();
      return null;
    }
    if (item is StreamSink) return item.close().then<void>((_) {});
    if (item is Sink) {
      item.close();
      return null;
    }
    if (item is FutureOr<void> Function()) return item();
    for (final adapter in LevitResourceDisposerSpi._adapters) {
      if (adapter.matches(item)) return adapter.dispose(item);
    }
    return null;
  }
}

final class _LevitResourceAdapter {
  final Object token;
  final bool Function(Object resource) matches;
  final FutureOr<void> Function(Object resource) dispose;

  const _LevitResourceAdapter({
    required this.token,
    required this.matches,
    required this.dispose,
  });
}

/// Service Provider Interface for registering external resource disposal
/// adapters with [LevitController.own] and [LevitRef.own].
///
/// Platform packages such as `levit_flutter_core` use this SPI to teach
/// `own(...)` how to dispose platform-specific types (for example Flutter's
/// `ChangeNotifier`) without coupling `levit_dart_core` to platform SDKs.
abstract final class LevitResourceDisposerSpi {
  static final List<_LevitResourceAdapter> _adapters = [];

  /// Registers a resource disposal adapter keyed by [token].
  ///
  /// Re-registering the same [token] replaces the existing adapter entry,
  /// keeping registration idempotent.
  static void registerAdapter({
    required Object token,
    required bool Function(Object resource) matches,
    required FutureOr<void> Function(Object resource) dispose,
  }) {
    final entry = _LevitResourceAdapter(
      token: token,
      matches: matches,
      dispose: dispose,
    );
    final existingIndex = _adapters.indexWhere((a) => a.token == token);
    if (existingIndex >= 0) {
      _adapters[existingIndex] = entry;
    } else {
      _adapters.add(entry);
    }
  }

  /// Removes the adapter registered under [token], if any.
  static bool unregisterAdapter(Object token) {
    final initialLength = _adapters.length;
    _adapters.removeWhere((a) => a.token == token);
    return _adapters.length != initialLength;
  }

  /// Returns `true` when an adapter is registered under [token].
  static bool hasAdapter(Object token) =>
      _adapters.any((a) => a.token == token);
}

/// Fluent extensions for naming and configuring reactive objects.
///
/// {@category Reactive State}
extension LxNamingExtension<R extends LxReactive> on R {
  /// Assigns a debug [name] to this reactive object and returns `this`.
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
