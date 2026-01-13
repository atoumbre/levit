import 'dart:async';

import 'package:meta/meta.dart';
import 'middleware.dart';

// ============================================================================
// Disposable Interface
// ============================================================================

/// Interface for objects that require lifecycle management.
///
/// Implement this interface in your controllers or services to receive callbacks
/// when the object is initialized ([onInit]) or disposed ([onClose]).
abstract class LevitScopeDisposable {
  /// Base constructor.
  const LevitScopeDisposable();

  /// Called immediately after the instance is registered via [Levit.put] or
  /// instantiated via [Levit.lazyPut] or [Levit.find].
  ///
  /// Use this method for setup logic, such as initializing variables or
  /// starting listeners.
  void onInit() {}

  /// [scope] is the [LevitScope] that created/owns this object.
  /// [key] is the registration key (e.g. "MyController" or "MyController_tag").
  /// Override this method to receive a reference to your scope, or to perform
  /// post-resolution setup that requires scope access.
  ///
  /// Note: This is called AFTER [onInit] completes.
  void didAttachToScope(LevitScope scope, {String? key}) {}

  /// Called when the instance is removed from the container via [Levit.delete]
  /// or during a [Levit.reset] call.
  ///
  /// Use this method for cleanup logic, such as closing streams or disposing
  /// of other resources.
  void onClose() {}
}

// ============================================================================
// Instance Info
// ============================================================================

/// Holds metadata about a registered dependency instance.
///
/// This class tracks the lifecycle state, creation strategy (factory, lazy, etc.),
/// and the instance itself.
///
/// It exists to support the internal mechanisms of [LevitScope] and is typically
/// not used directly by application code.
class LevitBindingEntry<S> {
  /// The actual instance, or `null` if it is a lazy registration that has not
  /// yet been instantiated.
  S? instance;

  /// The builder function for lazy instantiation.
  final S Function()? builder;

  /// The async builder function for lazy asynchronous instantiation.
  final Future<S> Function()? asyncBuilder;

  /// Whether the instance should persist even when a reset is requested (unless forced).
  final bool permanent;

  /// Whether this registration was made via `lazyPut`.
  final bool isLazy;

  /// Whether this registration is a factory (creates a new instance every time).
  final bool isFactory;

  /// Returns `true` if the lazy instance has been created.
  bool get isInstantiated => instance != null;

  /// Returns `true` if this registration uses an asynchronous builder.
  bool get isAsync => asyncBuilder != null;

  /// Creates a new [LevitBindingEntry] with the specified configuration.
  LevitBindingEntry({
    this.instance,
    this.builder,
    this.asyncBuilder,
    this.permanent = false,
    this.isLazy = false,
    this.isFactory = false,
  });
}

// ============================================================================
// LevitScope - Scoped Container
// ============================================================================

/// A scoped dependency injection container.
///
/// [LevitScope] manages a registry of dependencies. Scopes can be nested;
/// child scopes can override parent dependencies locally and automatically
/// clean up their own resources when disposed. Dependency lookups fall back
/// to the parent scope if the key is not found locally.
///
/// Use this class to create isolated environments for tests or modular parts
/// of your application (e.g., authenticated vs. guest scope).
class LevitScope {
  /// Static counter for generating unique scope IDs.
  static int _nextId = 0;

  /// Unique identifier for this scope instance.
  final int id;

  /// The name of this scope, used for debugging purposes.
  final String name;

  /// The parent scope, or `null` if this is the root scope.
  final LevitScope? _parentScope;

  /// The local registry of dependencies for this scope.
  final Map<String, LevitBindingEntry> _registry = {};

  /// A cache for resolved keys to speed up lookups in parent scopes.
  final Map<String, LevitScope> _resolutionCache = {};

  /// Creates a new [LevitScope]. Internal constructor.
  LevitScope._(this.name, {LevitScope? parentScope})
      : id = _nextId++,
        _parentScope = parentScope;

  /// Creates a new root [LevitScope].
  factory LevitScope.root([String? name]) => LevitScope._(name ?? 'root');

  // --------------------------------------------------------------------------
  // Registration
  // --------------------------------------------------------------------------

  /// Registers a dependency instance in this scope.
  ///
  /// The [builder] is executed immediately, wrapped in any registered hooks
  /// to enable automatic capture of reactive variables.
  ///
  /// If an instance with the same type and [tag] already exists, it is replaced.
  /// If the existing instance implements [LevitScopeDisposable], its [LevitScopeDisposable.onClose] method is called.
  ///
  /// If the created instance implements [LevitScopeDisposable], its [LevitScopeDisposable.onInit] method is called immediately.
  ///
  /// *   [builder]: A function that creates the instance.
  /// *   [tag]: An optional tag to distinguish multiple instances of the same type.
  /// *   [permanent]: If `true`, the instance will not be removed during a non-forced reset.
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final key = _getKey<S>(tag);

    if (_registry.containsKey(key)) {
      delete<S>(tag: tag, force: true);
    }

    final info = LevitBindingEntry<S>(permanent: permanent);

    // Instance creation logic shifted here to allow hook access to 'info'
    info.instance = _createInstance<S>(builder, key, info);

    _registerBinding(key, info, 'put');

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

    final info = LevitBindingEntry<S>(
      builder: builder,
      permanent: permanent ||
          isFactory, // Factories are usually permanent? Legacy code forced true.
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(key, info, isFactory ? 'putFactory' : 'lazyPut');
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

    final info = LevitBindingEntry<S>(
      asyncBuilder: builder,
      permanent: permanent || isFactory,
      isLazy: true,
      isFactory: isFactory,
    );

    _registerBinding(key, info, isFactory ? 'putFactoryAsync' : 'lazyPutAsync');
  }

  // --------------------------------------------------------------------------
  // Registration Helpers
  // --------------------------------------------------------------------------

  void _registerBinding<S>(
    String key,
    LevitBindingEntry<S> info,
    String source,
  ) {
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

    if (_resolutionCache.isNotEmpty) {
      _resolutionCache.remove(key);
    }

    _notifyRegister(key, info, source);
  }

  // --------------------------------------------------------------------------
  // Retrieval
  // --------------------------------------------------------------------------

  /// Finds and returns the registered instance of type [S].
  ///
  /// If the instance is not found in the current scope, the parent scope is checked.
  ///
  /// Throws an [Exception] if the dependency is not registered.
  ///
  /// *   [tag]: An optional tag to specify the instance.
  S find<S>({String? tag}) {
    final key = _getKey<S>(tag);

    // 1. Try Local Registry (Fastest Path)
    final info = _registry[key];
    if (info != null) {
      return _findLocal<S>(info as LevitBindingEntry<S>, key, tag);
    }

    // 2. Try Cache (Recursive Path)
    final cachedScope = _resolutionCache[key];
    if (cachedScope != null) {
      // Direct call to avoid redundant checks in parent
      return cachedScope.find<S>(tag: tag);
    }

    // 3. Try Parent (Recursive Path)
    if (_parentScope != null) {
      // We use findOrNull logic here to detect if it exists, but efficient:
      // Actually, if we call parent.find(), it throws if not found.
      // But we want to cache the scope if found.
      try {
        final instance = _parentScope!.find<S>(tag: tag);
        _cacheScope(key, _parentScope!);
        return instance;
      } catch (_) {
        // Fallthrough to throw below
      }
    }

    throw Exception(
      'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is not registered.\n'
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
      return _findLocal<S>(info as LevitBindingEntry<S>, key, tag);
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
      return _findLocalAsync<S>(info as LevitBindingEntry<S>, key, tag);
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
      return _findLocalAsync<S>(info as LevitBindingEntry<S>, key, tag);
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
      LevitBindingEntry<S> info, String key, String? tag) async {
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

  S _findLocal<S>(LevitBindingEntry<S> info, String key, String? tag) {
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

  S _createInstance<S>(
      S Function() builder, String key, LevitBindingEntry info) {
    final wrappedBuilder = _applyCreateInstanceHooks<S>(builder, key, info);
    return wrappedBuilder();
  }

  Future<S> _createInstanceAsync<S>(
      Future<S> Function() builder, String key, LevitBindingEntry info) async {
    final wrappedBuilder =
        _applyCreateInstanceHooks<Future<S>>(builder, key, info);
    return wrappedBuilder();
  }

  void _initializeInstance(
      dynamic instance, String key, LevitBindingEntry info) {
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

  // --------------------------------------------------------------------------
  // Deletion
  // --------------------------------------------------------------------------

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
    _pendingInit.remove(key); // Also clear any pending init
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
  }

  // --------------------------------------------------------------------------
  // Nested Scopes
  // --------------------------------------------------------------------------

  /// Creates a new child scope that falls back to this scope for dependency resolution.
  ///
  /// *   [name]: The name of the new scope.
  LevitScope createScope(String name) {
    return LevitScope._(name, parentScope: this);
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

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

  // --------------------------------------------------------------------------
  // Observers
  // --------------------------------------------------------------------------

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

  void _notifyRegister(String key, LevitBindingEntry info, String source) {
    LevitScopeMiddlewareChain.applyOnRegister(
        id, name, key, info, source, _parentScope?.id);
  }

  void _notifyResolve(String key, LevitBindingEntry info, String source) {
    LevitScopeMiddlewareChain.applyOnResolve(
        id, name, key, info, source, _parentScope?.id);
  }

  S Function() _applyCreateInstanceHooks<S>(
    S Function() builder,
    String key,
    LevitBindingEntry info,
  ) {
    return LevitScopeMiddlewareChain.applyOnCreate<S>(builder, this, key, info);
  }

  void _notifyDelete(String key, LevitBindingEntry info, String source) {
    LevitScopeMiddlewareChain.applyOnDelete(
        id, name, key, info, source, _parentScope?.id);
  }

  void _applyInitHooks<S>(
    S instance,
    void Function() onInit,
    String key,
    LevitBindingEntry info,
  ) {
    final wrapped = LevitScopeMiddlewareChain.applyOnDependencyInit<S>(
        onInit, instance, this, key, info);
    wrapped();
  }
}

// ----------------------------------------------------------------------------
// Internal: Observer Chain Applicator
// ----------------------------------------------------------------------------

/// Internal helper to apply observer hooks in a single place.
///
/// Consolidates iteration logic for better maintainability and optimization.
@internal
class LevitScopeMiddlewareChain {
  static S Function() applyOnCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitBindingEntry info,
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
    LevitBindingEntry info,
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
      LevitBindingEntry info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onRegister(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnResolve(int scopeId, String scopeName, String key,
      LevitBindingEntry info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onResolve(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }

  static void applyOnDelete(int scopeId, String scopeName, String key,
      LevitBindingEntry info, String source, int? parentScopeId) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDelete(scopeId, scopeName, key, info,
          source: source, parentScopeId: parentScopeId);
    }
  }
}

/// Extension to convert any object to a builder function.
extension LevitScopeToBuilderExtension<T> on T {
  T Function() get toBuilder => () => this;
}
