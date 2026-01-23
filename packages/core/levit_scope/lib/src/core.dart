import 'dart:async';

import 'package:meta/meta.dart';
import 'middleware.dart';

/// Interface for objects that require explicit lifecycle management within a [LevitScope].
///
/// Implement this interface in controllers or services to participate in
/// deterministic initialization ([onInit]) and cleanup ([onClose]).
///
/// ### Architectural Rationale
/// Manual resource management is prone to errors. By implementing this interface,
/// components can ensure their internal state is initialized only when requested
/// and cleaned up immediately when no longer needed, preventing memory leaks
/// and stale listeners.
abstract class LevitScopeDisposable {
  /// Base constructor.
  const LevitScopeDisposable();

  /// Callback invoked after the instance is instantiated but before it is used.
  ///
  /// Use this method for isolated setup logic such as starting persistent
  /// listeners or initializing reactive variables.
  void onInit() {}

  /// Callback invoked when the instance is attached to its owning [LevitScope].
  ///
  /// Parameters:
  /// - [scope]: The [LevitScope] that manages this object.
  /// - [key]: The unique registration key within the scope.
  ///
  /// This is called after [onInit] and before the instance is returned to callers.
  void didAttachToScope(LevitScope scope, {String? key}) {}

  /// Callback invoked when the instance is disposed.
  ///
  /// This occurs when the instance is explicitly removed via [LevitScope.delete]
  /// or when its owning scope is disposed. Use this method to cancel timers,
  /// close streams, or release other system resources.
  void onClose() {}
}

/// Holds metadata and the instance of a registered dependency.
///
/// [LevitDependency] tracks the lifecycle state, creation strategy, and
/// persistence of a dependency within a [LevitScope].
class LevitDependency<S> {
  /// The resolved instance, or `null` if not yet instantiated.
  S? instance;

  /// The synchronous builder function for lazy instantiation.
  final S Function()? builder;

  /// The asynchronous builder function for lazy instantiation.
  final Future<S> Function()? asyncBuilder;

  /// If `true`, the registration survives a non-forced [LevitScope.reset].
  final bool permanent;

  /// If `true`, the dependency is deferred until first requested.
  final bool isLazy;

  /// If `true`, a new instance is created for every resolution request.
  final bool isFactory;

  /// Returns `true` if the instance has been created.
  bool get isInstantiated => instance != null;

  /// Returns `true` if this registration uses an asynchronous builder.
  bool get isAsync => asyncBuilder != null;

  /// Internal constructor for creating dependency metadata.
  LevitDependency({
    this.instance,
    this.builder,
    this.asyncBuilder,
    this.permanent = false,
    this.isLazy = false,
    this.isFactory = false,
  });
}

/// A hierarchical dependency injection container.
///
/// [LevitScope] manages a registry of dependencies and their lifecycles.
/// Scopes can be nested to form a tree; child scopes can override parent
/// dependencies and provide isolated environments for features or tests.
///
/// ### Scoping Rules
/// 1.  **Resolution**: When [find] is called, the scope searches its local
///     registry. If not found, it recursively searches its parent scopes.
/// 2.  **Isolation**: Dependencies registered in a child scope are not
///     visible to parent scopes.
/// 3.  **Cleanup**: Disposing a scope automatically disposes all dependencies
///     registered within it that implement [LevitScopeDisposable].
///
/// ### Architectural Rationale
/// Scoping allows for deterministic resource management and modularity. It
/// enables patterns like "User Scopes" (where services are tied to a session)
/// or "Feature Scopes" (where resources are allocated only while a feature is active).
class LevitScope {
  /// Static counter for generating unique scope IDs.
  static int _nextId = 0;

  /// Unique identifier for this scope instance.
  final int id;

  /// The name of this scope, used for debugging purposes.
  final String name;

  /// The parent scope, or `null` if this is the root scope.
  final LevitScope? _parentScope;

  /// The local registry of dependencies for this scope (with tags).
  final Map<String, LevitDependency> _registry = {};

  /// Fast-path registry for tag-less lookups (Type -> Binding).
  /// This avoids string key generation for the common case.
  final Map<Type, LevitDependency> _typeRegistry = {};

  /// Ultra-fast instance cache for tag-less singleton lookups.
  /// Stores the actual instance directly, bypassing LevitDependency.
  final Map<Type, dynamic> _instanceCache = {};

  /// A cache for resolved keys to speed up lookups in parent scopes.
  final Map<String, LevitScope> _resolutionCache = {};

  /// Fast-path cache for tag-less parent scope lookups.
  final Map<Type, LevitScope> _typeResolutionCache = {};

  /// Creates a new [LevitScope]. Internal constructor.
  LevitScope._(this.name, {LevitScope? parentScope})
      : id = _nextId++,
        _parentScope = parentScope;

  /// Creates a new root [LevitScope].
  factory LevitScope.root([String? name]) => LevitScope._(name ?? 'root');

  /// Instantiates and registers a dependency instance in this scope.
  ///
  /// The [builder] is executed immediately. If an instance of type [S] with
  /// the same [tag] already exists, it is replaced and the old instance is disposed.
  ///
  /// // Example usage:
  /// ```dart
  /// scope.put(() => AuthService());
  /// ```
  ///
  /// Parameters:
  /// - [builder]: A function that creates the instance.
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the instance survives a non-forced [reset].
  ///
  /// Returns the created instance of type [S].
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key)) {
      delete<S>(tag: tag, force: true);
    }

    final info = LevitDependency<S>(permanent: permanent);

    // Instance creation logic shifted here to allow hook access to 'info'
    info.instance = _createInstance<S>(builder, key, info);

    _registerBinding(key, info, 'put', tag: tag);

    _initializeInstance(info.instance, key, info);

    return info.instance as S;
  }

  /// Registers a lazy builder in this scope.
  ///
  /// The [builder] is executed only when the dependency is first requested via [find].
  ///
  /// *   [builder]: The function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    final key = _getKey<S>(tag);

    // If it's a factory, we don't care if it's "instantiated" because it never really is (it's a production line)
    // But we might want to prevent overwriting if it's already registered?
    // Current logic: if registry has key & instantiated (for lazy singleton), return.
    // For factory: isInstantiated is always false.
    // So overwriting factory is allowed?
    // Old logic: lazyPut returns early if instantiated.
    // Factory logic: overwrites.

    if (!isFactory &&
        _registry.containsKey(key) &&
        _registry[key]!.isInstantiated) {
      return;
    }

    final info = LevitDependency<S>(
      builder: builder,
      permanent: permanent ||
          isFactory, // Factories are usually permanent? Legacy code forced true.
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(key, info, isFactory ? 'putFactory' : 'lazyPut', tag: tag);
  }

  /// Registers an asynchronous lazy builder in this scope.
  ///
  /// The [builder] is executed only when the dependency is first requested via [findAsync].
  ///
  /// *   [builder]: The async function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  void lazyPutAsync<S>(
    Future<S> Function() builder, {
    String? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    final key = _getKey<S>(tag);

    if (!isFactory &&
        _registry.containsKey(key) &&
        _registry[key]!.isInstantiated) {
      return;
    }

    final info = LevitDependency<S>(
      asyncBuilder: builder,
      permanent: permanent || isFactory,
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(key, info, isFactory ? 'putFactoryAsync' : 'lazyPutAsync',
        tag: tag);
  }

  void _registerBinding<S>(
    String key,
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

    _notifyRegister(key, info, source);
  }

  /// Retrieves the registered instance of type [S].
  ///
  /// If the dependency is not found in the current scope, it recursively
  /// searches parent scopes.
  ///
  /// Parameters:
  /// - [tag]: Optional unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found for [S] and [tag].
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
        final result =
            _findLocal<S>(info as LevitDependency<S>, S.toString(), null);
        // Cache if it's a singleton (not factory)
        if (!info.isFactory && info.instance != null) {
          _instanceCache[S] = info.instance;
        }
        return result;
      }

      // Try cached parent scope (Type-based)
      final cachedScope = _typeResolutionCache[S];
      if (cachedScope != null) {
        return cachedScope.find<S>();
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

    final info = _registry[key];
    if (info != null) {
      return _findLocal<S>(info as LevitDependency<S>, key, tag);
    }

    // Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      return cachedScope.find<S>(tag: tag);
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

  /// Finds and returns the registered instance of type [S], or `null` if not found.
  ///
  /// If the instance is not found in the current scope, the parent scope is checked.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  S? findOrNull<S>({String? tag}) {
    final key = _getKey<S>(tag);

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      return _findLocal<S>(info as LevitDependency<S>, key, tag);
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      return cachedScope.findOrNull<S>(tag: tag);
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

  /// Asynchronously finds and returns a registered instance of type [S].
  ///
  /// Use this for dependencies registered via [lazyPutAsync] or [createAsync].
  ///
  /// Throws an [Exception] if the dependency is not registered.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  Future<S> findAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      return _findLocalAsync<S>(info as LevitDependency<S>, key, tag);
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      return cachedScope.findAsync<S>(tag: tag);
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

  /// Asynchronously finds an instance of type [S], returning `null` if not found.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  Future<S?> findOrNullAsync<S>({String? tag}) async {
    final key = _getKey<S>(tag);

    // 1. Try Local
    final info = _registry[key];
    if (info != null) {
      return _findLocalAsync<S>(info as LevitDependency<S>, key, tag);
    }

    // 2. Try Cache
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      return cachedScope.findOrNullAsync<S>(tag: tag);
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

  void _cacheScope(String key, LevitScope scope) {
    if (scope._resolutionCache.containsKey(key)) {
      _resolutionCache[key] = scope._resolutionCache[key]!;
    } else {
      _resolutionCache[key] = scope;
    }
  }

  // Cache for in-flight async initializations to prevent race conditions
  final Map<String, Future<dynamic>> _pendingInit = {};

  Future<S> _findLocalAsync<S>(
      LevitDependency<S> info, String key, String? tag) async {
    if (info.isInstantiated) {
      return info.instance as S;
    }

    // Handle Async Factory
    if (info.isFactory && info.isAsync) {
      final instance =
          await _createInstanceAsync<S>(info.asyncBuilder!, key, info);
      _initializeInstance(instance, key, info);
      _notifyResolve(key, info, 'findAsync');
      return instance;
    }

    // Handle Sync Factory
    if (info.isFactory && info.builder != null) {
      final instance = _createInstance<S>(info.builder!, key, info);
      _initializeInstance(instance, key, info);
      _notifyResolve(key, info, 'findAsync');
      return instance;
    }

    // Handle Lazy Async Singleton
    if (info.isLazy && info.isAsync) {
      if (_pendingInit.containsKey(key)) {
        return await _pendingInit[key] as S;
      }

      final future = (() async {
        try {
          final instance =
              await _createInstanceAsync<S>(info.asyncBuilder!, key, info);
          info.instance = instance;
          _initializeInstance(instance, key, info);
          _notifyResolve(key, info, 'findAsync');
          return instance;
        } finally {
          _pendingInit.remove(key);
        }
      })();

      _pendingInit[key] = future;
      return future;
    }

    // Fallback to sync local find (e.g. for standard lazyPut accessed via findAsync)
    return _findLocal<S>(info, key, tag);
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

  /// Returns `true` if type [S] is registered in this specific scope.
  bool isRegisteredLocally<S>({String? tag}) {
    return _registry.containsKey(_getKey<S>(tag));
  }

  /// Returns `true` if type [S] is registered in this scope or any parent scope.
  bool isRegistered<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) return true;
    if (_parentScope != null) return _parentScope!.isRegistered<S>(tag: tag);
    return false;
  }

  /// Returns `true` if type [S] is registered and has been instantiated.
  bool isInstantiated<S>({String? tag}) {
    if (isRegisteredLocally<S>(tag: tag)) {
      final key = _getKey<S>(tag);
      return _registry[key]!.isInstantiated;
    }
    if (_parentScope != null) return _parentScope!.isInstantiated<S>(tag: tag);
    return false;
  }

  /// Deletes an instance of type [S] from this scope.
  ///
  /// Returns `true` if the instance was successfully deleted.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  /// *   [force]: If `true`, deletes the instance even if it was registered as `permanent`.
  bool delete<S>({String? tag, bool force = false}) {
    final key = _getKey<S>(tag);

    if (!_registry.containsKey(key)) return false;

    final info = _registry[key]!;

    if (info.permanent && !force) return false;

    if (info.isInstantiated && info.instance is LevitScopeDisposable) {
      (info.instance as LevitScopeDisposable).onClose();
    }

    _notifyDelete(key, info, 'delete');

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

  /// Clears all instances in this scope only (does not affect parent scopes).
  ///
  /// *   [force]: If `true`, deletes all instances even if they were registered as `permanent`.
  void reset({bool force = false}) {
    final keysToRemove = <String>[];

    for (final entry in _registry.entries) {
      final info = entry.value;

      if (info.permanent && !force) continue;

      if (info.isInstantiated && info.instance is LevitScopeDisposable) {
        (info.instance as LevitScopeDisposable).onClose();
      }

      _notifyDelete(entry.key, info, 'reset');
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

  /// Creates a new child scope that falls back to this scope for dependency resolution.
  ///
  /// *   [name]: The name of the new scope.
  LevitScope createScope(String name) {
    return LevitScope._(name, parentScope: this);
  }

  static final Map<Type, String> _typeCache = {};

  String _getKey<S>(String? tag) {
    final typeString = _typeCache[S] ??= S.toString();
    final base = tag != null ? '${typeString}_$tag' : typeString;
    // Format: Type_tag
    return base;
  }

  /// The number of dependencies registered locally in this scope.
  int get registeredCount => _registry.length;

  /// A list of keys for all locally registered dependencies (for debugging).
  List<String> get registeredKeys => _registry.keys.toList();

  @override
  String toString() =>
      'LevitScope($name, ${_registry.length} local registrations)';

  // Middleware System
  static final List<LevitScopeMiddleware> _middlewares = [];

  /// Adds a global middleware to be notified of DI events.
  static void addMiddleware(LevitScopeMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Removes a previously added middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    _middlewares.remove(middleware);
  }

  /// Whether any middlewares are registered.
  static bool get hasMiddlewares => _middlewares.isNotEmpty;

  void _notifyRegister(String key, LevitDependency info, String source) {
    LevitScopeMiddlewareChain.applyOnRegister(
        id, name, key, info, source, _parentScope?.id);
  }

  void _notifyResolve(String key, LevitDependency info, String source) {
    LevitScopeMiddlewareChain.applyOnResolve(
        id, name, key, info, source, _parentScope?.id);
  }

  S Function() _applyCreateInstanceHooks<S>(
    S Function() builder,
    String key,
    LevitDependency info,
  ) {
    return LevitScopeMiddlewareChain.applyOnCreate<S>(builder, this, key, info);
  }

  void _notifyDelete(String key, LevitDependency info, String source) {
    LevitScopeMiddlewareChain.applyOnDelete(
        id, name, key, info, source, _parentScope?.id);
  }

  void _applyInitHooks<S>(
    S instance,
    void Function() onInit,
    String key,
    LevitDependency info,
  ) {
    final wrapped = LevitScopeMiddlewareChain.applyOnDependencyInit<S>(
        onInit, instance, this, key, info);
    wrapped();
  }
}

/// Internal helper to apply observer hooks in a single place.
///
/// Consolidates iteration logic for better maintainability and optimization.
@internal
class LevitScopeMiddlewareChain {
  static S Function() applyOnCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    if (LevitScope._middlewares.isEmpty) return builder;
    var wrapped = builder;
    for (final observer in LevitScope._middlewares) {
      wrapped = observer.onCreate<S>(wrapped, scope, key, info);
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
      observer.onRegister(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnResolve(int scopeId, String scopeName, String key,
      LevitDependency info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onResolve(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnDelete(int scopeId, String scopeName, String key,
      LevitDependency info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDelete(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }
}

/// Extension to convert any object to a builder function.
extension LevitScopeToBuilderExtension<T> on T {
  /// Converts the current instance into a lazy builder function that returns it.
  T Function() get toBuilder => () => this;
}
