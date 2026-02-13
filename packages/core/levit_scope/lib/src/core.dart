part of '../levit_scope.dart';

/// An interface for objects that participate in the [LevitScope] lifecycle.
///
/// Implement this interface to receive callbacks for initialization and disposal.
/// This mechanism ensures deterministic cleanup when the owning scope is disposed.
///
/// Example:
/// ```dart
/// class MyService implements LevitScopeDisposable {
///   @override
///   void onInit() {
///     print('Service initialized');
///   }
///
///   @override
///   void onClose() {
///     print('Service disposed');
///   }
/// }
/// ```
abstract class LevitScopeDisposable {
  /// Creates a [LevitScopeDisposable].
  const LevitScopeDisposable();

  /// Called immediately after the object is instantiated.
  ///
  /// Use this method for isolated initialization logic, such as setting up
  /// internal state or starting independent listeners. This runs before the
  /// object is returned to the caller.
  void onInit() {}

  /// Called when the object is attached to a [LevitScope].
  ///
  /// This occurs after [onInit]. Use this callback if your initialization
  /// logic requires access to the scope itself or the registration [key].
  ///
  /// [scope] is the [LevitScope] that manages this object.
  /// [key] is the unique registration key associated with this instance.
  void didAttachToScope(LevitScope scope, {String? key}) {}

  /// Called when the object is removed from the scope or the scope is disposed.
  ///
  /// Use this method to release resources, close streams, or cancel timers.
  void onClose() {}
}

/// Metadata container for a dependency registered within a [LevitScope].
///
/// This class tracks the lifecycle state, creation strategy, and persistence
/// settings for a specific registration.
class LevitDependency<S> {
  /// The resolved instance, or `null` if not yet instantiated.
  S? instance;

  /// The synchronous builder function for lazy or factory instantiation.
  final S Function()? builder;

  /// The asynchronous builder function for async instantiation.
  final Future<S> Function()? asyncBuilder;

  /// Whether the registration persists across a non-forced [LevitScope.reset].
  final bool permanent;

  /// Whether the instance creation is deferred until the first lookup.
  final bool isLazy;

  /// Whether a new instance is created for every lookup.
  final bool isFactory;

  /// Whether the [instance] has been created and is currently active.
  bool get isInstantiated => instance != null;

  /// Whether this registration uses an asynchronous builder.
  bool get isAsync => asyncBuilder != null;

  /// Creates metadata for a dependency registration.
  LevitDependency({
    this.instance,
    this.builder,
    this.asyncBuilder,
    this.permanent = false,
    this.isLazy = false,
    this.isFactory = false,
  });
}

/// Typed key for dependency registrations.
///
/// This avoids relying on `Type.toString()` (or `S.toString()`) for identity,
/// which can change under obfuscation/minification. String representations are
/// kept for debugging/middleware only.
class LevitScopeKey {
  static final Map<Type, String> _debugTypeCache = {};

  final Type type;
  final String? tag;

  const LevitScopeKey(this.type, this.tag);

  static LevitScopeKey of<S>({String? tag}) => LevitScopeKey(S, tag);

  String get debugString {
    final typeString = _debugTypeCache[type] ??= type.toString();
    if (tag == null) return typeString;
    // Preserve historical format: Type_tag
    return '${typeString}_$tag';
  }

  @override
  String toString() => debugString;

  @override
  bool operator ==(Object other) =>
      other is LevitScopeKey && other.type == type && other.tag == tag;

  @override
  int get hashCode => Object.hash(type, tag);
}

/// A hierarchical dependency injection container.
///
/// [LevitScope] manages the lifecycle of dependencies, supports hierarchical
/// scoping, and allows for deterministic cleanup.
///
/// ## Resolution Rules
/// 1.  **Local Check**: Searches the current scope's registry first.
/// 2.  **Parent Delegation**: If not found locally, recursively searches parent scopes.
/// 3.  **Isolation**: Dependencies registered in a child scope are not visible to parents.
///
/// ## Lifecycle
/// When a scope is disposed via [dispose]:
/// *   All locally registered dependencies implementing [LevitScopeDisposable]
///     will receive a [LevitScopeDisposable.onClose] callback.
/// *   The scope becomes unusable and should be discarded.
class LevitScope {
  /// Internal counter for unique scope IDs.
  static int _nextId = 0;

  /// The unique identifier for this scope.
  final int id;

  /// A descriptive name for debugging.
  final String name;

  /// The parent scope, or `null` if this is the root scope.
  final LevitScope? _parentScope;

  /// The local registry of dependencies (Key -> Metadata).
  final Map<LevitScopeKey, LevitDependency> _registry = {};

  /// Fast-path registry for tag-less lookups (Type -> Metadata).
  final Map<Type, LevitDependency> _typeRegistry = {};

  /// Ultra-fast instance cache for tag-less singletons.
  final Map<Type, dynamic> _instanceCache = {};

  /// Cache for resolved keys to speed up parent scope lookups.
  final Map<LevitScopeKey, LevitScope> _resolutionCache = {};

  /// Fast-path cache for tag-less parent scope lookups.
  final Map<Type, LevitScope> _typeResolutionCache = {};

  /// Creates a new [LevitScope].
  LevitScope._(this.name, {LevitScope? parentScope})
      : id = _nextId++,
        _parentScope = parentScope {
    _notifyScopeCreate();
  }

  /// Creates a new root [LevitScope].
  ///
  /// The root scope has no parent and typically lives for the duration of the app.
  ///
  /// [name] defaults to `'root'` if not provided.
  factory LevitScope.root([String? name]) => LevitScope._(name ?? 'root');

  /// Immediately instantiates and registers a dependency.
  ///
  /// The [builder] is called immediately. If a dependency of type [S] with the
  /// same [tag] already exists, it is replaced (disposed) before the new one is created.
  ///
  /// Example:
  /// ```dart
  /// scope.put(() => AuthService());
  /// ```
  ///
  /// Use [permanent] to prevent the dependency from being disposed during a [reset].
  ///
  /// Returns the created instance.
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    if (_registry.containsKey(key)) {
      delete<S>(tag: tag, force: true);
    }

    final info = LevitDependency<S>(permanent: permanent);

    // Instance creation logic shifted here to allow hook access to 'info'
    info.instance = _createInstance<S>(builder, keyString, info);

    _registerBinding(key, keyString, info, 'put', tag: tag);

    _initializeInstance(info.instance, keyString, info);

    return info.instance as S;
  }

  /// Registers a dependency to be lazily instantiated.
  ///
  /// The [builder] is only executed when the dependency is first requested via [find].
  ///
  /// If [isFactory] is `true`, a new instance will be created for *every* request.
  /// Otherwise (default), the instance is cached and treated as a singleton within this scope.
  ///
  /// Use [permanent] to prevent the registration from being cleared during a [reset].
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    if (!isFactory &&
        _registry.containsKey(key) &&
        _registry[key]!.isInstantiated) {
      return;
    }

    final info = LevitDependency<S>(
      builder: builder,
      permanent: permanent || isFactory,
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(
      key,
      keyString,
      info,
      isFactory ? 'putFactory' : 'lazyPut',
      tag: tag,
    );
  }

  /// Registers an asynchronous dependency to be lazily instantiated.
  ///
  /// The [builder] is only executed when the dependency is first requested via [findAsync].
  ///
  /// If [isFactory] is `true`, the builder is called for *every* request.
  /// Otherwise, the result is cached.
  ///
  /// Returns a function that allows retrieving the dependency (shortcut for `findAsync`).
  Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    String? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    if (!isFactory &&
        _registry.containsKey(key) &&
        _registry[key]!.isInstantiated) {
      return () => findAsync<S>(tag: tag);
    }

    final info = LevitDependency<S>(
      asyncBuilder: builder,
      permanent: permanent || isFactory,
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(
      key,
      keyString,
      info,
      isFactory ? 'putFactoryAsync' : 'lazyPutAsync',
      tag: tag,
    );

    return () => findAsync<S>(tag: tag);
  }

  void _registerBinding<S>(
    LevitScopeKey key,
    String keyString,
    LevitDependency<S> info,
    String source, {
    String? tag,
  }) {
    if (_registry.containsKey(key)) {
      if (info.isLazy || info.isFactory) {
        // For lazy/factory, only replace if not instantiated or if we really want to overwrite.
        // But put() logic typically deletes first. lazyPut checks existence.
        // Let's keep original semantics:
        // put: always overwrites (handled in put() by calling delete)
        // lazyPut: returns early if exists & instantiated.
      }
    }

    _registry[key] = info;

    // Fast-path: also register by Type for tag-less registrations
    if (tag == null) {
      _typeRegistry[S] = info;
      _typeResolutionCache.remove(S);
    }

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }

    _notifyRegister(keyString, info, source);
  }

  /// Finds and returns a registered instance of type [S].
  ///
  /// This method performs a hierarchical lookup:
  /// 1.  **Local Check**: Checks the current scope.
  /// 2.  **Parent Check**: Recursively checks parent scopes.
  ///
  /// If the dependency is found but not yet instantiated (lazy), it will be created.
  ///
  /// Throws an [Exception] if [S] is not registered in this scope or any ancestor.
  S find<S>({String? tag}) {
    // ULTRA-FAST PATH: Direct instance cache lookup (no indirection)
    if (tag == null) {
      final cached = _instanceCache[S];
      if (cached != null) {
        return cached as S;
      }

      // Fast path: Type registry lookup
      final info = _typeRegistry[S];
      if (info != null) {
        // Already instantiated singleton - cache and return
        final instance = info.instance;
        if (instance != null && !info.isFactory) {
          _instanceCache[S] = instance;
          return instance as S;
        }
        // Slower path: needs instantiation
        final result = _findLocal<S>(
          info as LevitDependency<S>,
          LevitScopeKey.of<S>().debugString,
          null,
        );
        // Cache if it's a singleton (not factory)
        if (!info.isFactory && info.instance != null) {
          _instanceCache[S] = info.instance;
        }
        return result;
      }

      // Try cached parent scope (Type-based)
      final cachedScope = _typeResolutionCache[S];
      if (cachedScope != null) {
        try {
          return cachedScope.find<S>();
        } catch (_) {
          _typeResolutionCache.remove(S);
        }
      }

      // Try parent
      if (_parentScope != null) {
        try {
          final instance = _parentScope!.find<S>();
          _typeResolutionCache[S] = _parentScope!;
          return instance;
        } catch (_) {
          // Fallthrough to throw below
        }
      }

      throw Exception(
        'LevitScope($name): Type "$S" is not registered.\n'
        'Not found in scope or any parent.',
      );
    }

    // SLOW PATH: With tag - use String-based registry
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    final info = _registry[key];
    if (info != null) {
      return _findLocal<S>(info as LevitDependency<S>, keyString, tag);
    }

    // Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      try {
        return cachedScope.find<S>(tag: tag);
      } catch (_) {
        _resolutionCache.remove(key);
      }
    }

    // Try Parent
    if (_parentScope != null) {
      try {
        final instance = _parentScope!.find<S>(tag: tag);
        _cacheScope(key, _parentScope!);
        return instance;
      } catch (_) {
        // Fallthrough to throw below
      }
    }

    throw Exception(
      'LevitScope($name): Type "$S" with tag "$tag" is not registered.\n'
      'Not found in scope or any parent.',
    );
  }

  /// Finds and returns a registered instance of type [S], or `null` if not found.
  ///
  /// Mirrors the behavior of [find] but returns `null` instead of throwing an exception
  /// if the dependency is missing.
  S? findOrNull<S>({String? tag}) {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      try {
        return _findLocal<S>(info as LevitDependency<S>, keyString, tag);
      } catch (_) {
        return null;
      }
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      try {
        return cachedScope.findOrNull<S>(tag: tag);
      } catch (_) {
        _resolutionCache.remove(key);
      }
    }

    // 3. Try Parent
    if (_parentScope != null) {
      final instance = _parentScope!.findOrNull<S>(tag: tag);
      if (instance != null) {
        _cacheScope(key, _parentScope!);
        return instance;
      }
    }

    return null;
  }

  /// Finds and returns an asynchronously registered instance of type [S].
  ///
  /// Use this for dependencies registered via [lazyPutAsync].
  ///
  /// Throws an [Exception] if [S] is not registered.
  Future<S> findAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      return _findLocalAsync<S>(
          info as LevitDependency<S>, key, keyString, tag);
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      try {
        return await cachedScope.findAsync<S>(tag: tag);
      } catch (_) {
        _resolutionCache.remove(key);
      }
    }

    // 3. Try Parent
    if (_parentScope != null) {
      try {
        final instance = await _parentScope!.findAsync<S>(tag: tag);
        _cacheScope(key, _parentScope!);
        return instance;
      } catch (_) {}
    }

    throw Exception(
      'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is not registered.\n'
      'Not found in scope or any parent.',
    );
  }

  /// Asynchronously finds an instance of type [S], or returns `null` if not found.
  Future<S?> findOrNullAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      return _findLocalAsync<S>(
          info as LevitDependency<S>, key, keyString, tag);
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      try {
        return await cachedScope.findOrNullAsync<S>(tag: tag);
      } catch (_) {
        _resolutionCache.remove(key);
      }
    }

    // 3. Try Parent
    if (_parentScope != null) {
      final instance = await _parentScope!.findOrNullAsync<S>(tag: tag);
      if (instance != null) {
        _cacheScope(key, _parentScope!);
        return instance;
      }
    }

    return null;
  }

  void _cacheScope(LevitScopeKey key, LevitScope scope) {
    if (_resolutionCache.containsKey(key)) {
      _resolutionCache[key] = scope;
    } else {
      // Prevent unbounded growth from dynamic tags
      if (_resolutionCache.length > 500) {
        // Simple purge strategy: clear the cache if it gets too large.
        // We could do LRU, but cleared cache just means slower lookups, which is safe.
        _resolutionCache.clear();
      }
      _resolutionCache[key] = scope;
    }
  }

  // Cache for in-flight async initializations to prevent race conditions
  final Map<LevitScopeKey, Future<dynamic>> _pendingInit = {};

  Future<S> _findLocalAsync<S>(LevitDependency<S> info, LevitScopeKey key,
      String keyString, String? tag) async {
    if (info.isInstantiated) {
      return info.instance as S;
    }

    // Handle Async Factory
    if (info.isFactory && info.isAsync) {
      final instance =
          await _createInstanceAsync<S>(info.asyncBuilder!, keyString, info);
      _initializeInstance(instance, keyString, info);
      _notifyResolve(keyString, info, 'findAsync');
      return instance;
    }

    // Handle Sync Factory
    if (info.isFactory && info.builder != null) {
      final instance = _createInstance<S>(info.builder!, keyString, info);
      _initializeInstance(instance, keyString, info);
      _notifyResolve(keyString, info, 'findAsync');
      return instance;
    }

    // Handle Lazy Async Singleton
    if (info.isLazy && info.isAsync) {
      if (_pendingInit.containsKey(key)) {
        return await _pendingInit[key] as S;
      }

      final future = (() async {
        try {
          final instance = await _createInstanceAsync<S>(
              info.asyncBuilder!, keyString, info);
          if (!identical(_registry[key], info)) {
            if (instance is LevitScopeDisposable) {
              instance.onClose();
            }
            throw StateError(
              'LevitScope($name): Dependency "$keyString" was disposed while initializing.',
            );
          }

          info.instance = instance;
          _initializeInstance(instance, keyString, info);
          _notifyResolve(keyString, info, 'findAsync');
          return instance;
        } finally {
          _pendingInit.remove(key);
        }
      })();

      _pendingInit[key] = future;
      return future;
    }

    // Fallback to sync local find (e.g. for standard lazyPut accessed via findAsync)
    return _findLocal<S>(info, keyString, tag);
  }

  S _findLocal<S>(LevitDependency<S> info, String key, String? tag) {
    if (info.isAsync && !info.isInstantiated) {
      throw StateError(
        'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is registered as async and not yet instantiated. Use findAsync() to initialize it.',
      );
    }

    // Handle Sync Factory
    if (info.isFactory && info.builder != null) {
      final instance = _createInstance<S>(info.builder!, key, info);
      _initializeInstance(instance, key, info);
      _notifyResolve(key, info, 'find');
      return instance;
    }

    // Handle Lazy Sync Singleton
    if (info.isLazy && !info.isInstantiated) {
      info.instance = _createInstance<S>(info.builder!, key, info);
      _initializeInstance(info.instance, key, info);
      _notifyResolve(key, info, 'find');
    }

    return info.instance as S;
  }

  S _createInstance<S>(S Function() builder, String key, LevitDependency info) {
    final wrappedBuilder = _applyCreateInstanceHooks<S>(builder, key, info);
    return wrappedBuilder();
  }

  Future<S> _createInstanceAsync<S>(
      Future<S> Function() builder, String key, LevitDependency info) async {
    final wrappedBuilder =
        _applyCreateInstanceHooks<Future<S>>(builder, key, info);
    return wrappedBuilder();
  }

  void _initializeInstance(dynamic instance, String key, LevitDependency info) {
    if (instance is LevitScopeDisposable) {
      instance.didAttachToScope(this, key: key);
      _applyInitHooks(instance, instance.onInit, key, info);
    }
  }

  /// Returns `true` if type [S] is registered in this scope (parent scopes are ignored).
  bool isRegisteredLocally<S>({String? tag}) {
    return _registry.containsKey(_getKey<S>(tag));
  }

  /// Returns `true` if type [S] is registered in this scope or any ancestor.
  bool isRegistered<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) return true;
    if (_parentScope != null) return _parentScope!.isRegistered<S>(tag: tag);
    return false;
  }

  /// Returns `true` if the dependency [S] has already been instantiated.
  ///
  /// This checks if the lazy builder has executed or if the instance was put directly.
  bool isInstantiated<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) {
      final key = _getKey<S>(tag);
      return _registry[key]!.isInstantiated;
    }
    if (_parentScope != null) return _parentScope!.isInstantiated<S>(tag: tag);
    return false;
  }

  /// Removes a dependency from the scope.
  ///
  /// If the dependency is currently instantiated and implements [LevitScopeDisposable],
  /// its [LevitScopeDisposable.onClose] method will be called.
  ///
  /// Set [force] to `true` to delete dependencies marked as `permanent`.
  ///
  /// Returns `true` if the dependency was found and deleted.
  bool delete<S>({String? tag, bool force = false}) {
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    if (!_registry.containsKey(key)) return false;

    final info = _registry[key]!;

    if (info.permanent && !force) return false;

    if (info.isInstantiated && info.instance is LevitScopeDisposable) {
      (info.instance as LevitScopeDisposable).onClose();
    }

    _notifyDelete(keyString, info, 'delete');

    _registry.remove(key);
    _pendingInit.remove(key);

    // Also clear from fast-path registry if tag-less
    if (tag == null) {
      _typeRegistry.remove(S);
      _typeResolutionCache.remove(S);
      _instanceCache.remove(S);
    }

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }
    return true;
  }

  /// Disposes all dependencies registered in this scope.
  ///
  /// Dependencies marked as `permanent` are preserved unless [force] is `true`.
  void reset({bool force = false}) {
    final keysToRemove = <LevitScopeKey>[];

    for (final entry in _registry.entries) {
      final info = entry.value;

      if (info.permanent && !force) continue;

      if (info.isInstantiated && info.instance is LevitScopeDisposable) {
        (info.instance as LevitScopeDisposable).onClose();
      }

      _notifyDelete(entry.key.debugString, info, 'reset');
      keysToRemove.add(entry.key);
    }

    for (final key in keysToRemove) {
      _registry.remove(key);
      _pendingInit.remove(key);
      if (_resolutionCache.isNotEmpty) {
        _resolutionCache.remove(key);
      }
    }

    // Clear fast-path registries
    _typeRegistry.clear();
    _typeResolutionCache.clear();
    _instanceCache.clear();
  }

  /// Disposes the scope and all its dependencies.
  ///
  /// This triggers a full cleanup. All middlewares are notified, and the scope
  /// is marked as unusable.
  void dispose() {
    reset(force: true);
    _notifyScopeDispose();
  }

  /// Creates a new child scope.
  ///
  /// The child scope can register its own dependencies or shadow dependencies
  /// from this parent scope.
  ///
  /// [name] is used for debugging.
  LevitScope createScope(String name) {
    return LevitScope._(name, parentScope: this);
  }

  LevitScopeKey _getKey<S>(String? tag) => LevitScopeKey.of<S>(tag: tag);

  /// The number of dependencies registered locally in this scope.
  int get registeredCount => _registry.length;

  /// A list of keys for all locally registered dependencies (for debugging).
  List<String> get registeredKeys =>
      _registry.keys.map((k) => k.debugString).toList();

  @override
  String toString() =>
      'LevitScope($name, ${_registry.length} local registrations)';

  // Middleware System
  static final List<LevitScopeMiddleware> _middlewares = [];
  static final Map<Object, LevitScopeMiddleware> _middlewaresByToken = {};

  /// Adds a global middleware to be notified of DI events.
  ///
  /// Registration is idempotent by instance identity.
  /// If [token] is provided, registration is unique per token:
  /// adding another middleware with the same token replaces the previous one.
  static void addMiddleware(
    LevitScopeMiddleware middleware, {
    Object? token,
  }) {
    if (token != null) {
      final existingByToken = _middlewaresByToken[token];
      if (existingByToken != null) {
        if (identical(existingByToken, middleware)) {
          return;
        }

        final index = _middlewares.indexOf(existingByToken);
        if (index >= 0) {
          _middlewares[index] = middleware;
        } else {
          _middlewares.add(middleware);
        }
        _middlewaresByToken[token] = middleware;
        return;
      }

      if (_middlewares.contains(middleware)) {
        _middlewaresByToken[token] = middleware;
        return;
      }

      _middlewares.add(middleware);
      _middlewaresByToken[token] = middleware;
      return;
    }

    if (_middlewares.contains(middleware)) {
      return;
    }

    _middlewares.add(middleware);
  }

  /// Removes a previously added middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    final removed = _middlewares.remove(middleware);
    if (removed) {
      _middlewaresByToken
          .removeWhere((_, registered) => identical(registered, middleware));
    }
  }

  /// Removes a middleware by [token].
  static bool removeMiddlewareByToken(Object token) {
    final middleware = _middlewaresByToken.remove(token);
    if (middleware == null) return false;
    return _middlewares.remove(middleware);
  }

  /// Returns `true` if [middleware] is currently registered.
  static bool containsMiddleware(LevitScopeMiddleware middleware) {
    return _middlewares.contains(middleware);
  }

  /// Returns `true` if [token] is currently registered.
  static bool containsMiddlewareToken(Object token) {
    return _middlewaresByToken.containsKey(token);
  }

  /// Whether any middlewares are registered.
  static bool get hasMiddlewares => _middlewares.isNotEmpty;

  void _notifyRegister(String key, LevitDependency info, String source) {
    _LevitScopeMiddlewareChain.applyOnRegister(
        id, name, key, info, source, _parentScope?.id);
  }

  void _notifyResolve(String key, LevitDependency info, String source) {
    _LevitScopeMiddlewareChain.applyOnResolve(
        id, name, key, info, source, _parentScope?.id);
  }

  S Function() _applyCreateInstanceHooks<S>(
    S Function() builder,
    String key,
    LevitDependency info,
  ) {
    return _LevitScopeMiddlewareChain.applyOnCreate<S>(
        builder, this, key, info);
  }

  void _notifyDelete(String key, LevitDependency info, String source) {
    _LevitScopeMiddlewareChain.applyOnDelete(
        id, name, key, info, source, _parentScope?.id);
  }

  void _applyInitHooks<S>(
    S instance,
    void Function() onInit,
    String key,
    LevitDependency info,
  ) {
    final wrapped = _LevitScopeMiddlewareChain.applyOnDependencyInit<S>(
        onInit, instance, this, key, info);
    wrapped();
  }

  void _notifyScopeCreate() {
    _LevitScopeMiddlewareChain.applyOnScopeCreate(id, name, _parentScope?.id);
  }

  void _notifyScopeDispose() {
    _LevitScopeMiddlewareChain.applyOnScopeDispose(id, name);
  }
}

/// Internal helper to apply observer hooks in a single place.
///
/// Consolidates iteration logic for better maintainability and optimization.
class _LevitScopeMiddlewareChain {
  static S Function() applyOnCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    if (LevitScope._middlewares.isEmpty) return builder;
    var wrapped = builder;
    for (final observer in LevitScope._middlewares) {
      wrapped = observer.onDependencyCreate<S>(wrapped, scope, key, info);
    }
    return wrapped;
  }

  static void Function() applyOnDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    if (LevitScope._middlewares.isEmpty) return onInit;
    var wrapped = onInit;
    for (final observer in LevitScope._middlewares) {
      wrapped =
          observer.onDependencyInit<S>(wrapped, instance, scope, key, info);
    }
    return wrapped;
  }

  static void applyOnRegister(int scopeId, String scopeName, String key,
      LevitDependency info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDependencyRegister(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnResolve(int scopeId, String scopeName, String key,
      LevitDependency info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDependencyResolve(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnDelete(int scopeId, String scopeName, String key,
      LevitDependency info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDependencyDelete(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnScopeCreate(
      int scopeId, String scopeName, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onScopeCreate(scopeId, scopeName, parentScopeId);
    }
  }

  static void applyOnScopeDispose(int scopeId, String scopeName) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onScopeDispose(scopeId, scopeName);
    }
  }
}

/// Extension to convert any object to a builder function.
extension LevitScopeToBuilderExtension<T> on T {
  /// Converts the current instance into a lazy builder function that returns it.
  T Function() get toBuilder => () => this;
}
