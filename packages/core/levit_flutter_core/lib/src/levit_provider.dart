part of '../levit_flutter_core.dart';

/// Gateway for resolving and registering dependencies from a [BuildContext].
///
/// Accessed via `context.levit`. Proxies calls to the nearest [LScope] in the
/// widget tree (without subscribing the widget to rebuilds); if no widget scope
/// is present, falls back to [Levit.currentScope] (the active zone scope, or
/// the root scope).
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final controller = context.levit.find<CartController>();
///   return LWatch(() => Text('Items: ${controller.count()}'));
/// }
/// ```
///
/// {@category Flutter Widgets & Interop}
class LevitContext {
  final BuildContext _context;

  /// Creates a [LevitContext] bound to the given [BuildContext].
  LevitContext(this._context);

  LevitScope get _scope => _ScopeProvider.of(_context) ?? Levit.currentScope;

  /// Resolves a registered dependency of type [S] (optionally matching [tag])
  /// from the nearest widget scope or its ancestors.
  ///
  /// Throws if no matching registration exists.
  S find<S>({Object? tag}) => _scope.find<S>(tag: tag);

  /// Resolves a registered dependency of type [S] (optionally matching [tag]),
  /// returning `null` only when no registration exists. Builder errors propagate.
  S? findOrNull<S>({Object? tag}) => _scope.findOrNull<S>(tag: tag);

  /// Asynchronously resolves a dependency of type [S] (optionally matching
  /// [tag]) from the nearest widget scope or its ancestors.
  ///
  /// Throws if no matching registration exists.
  Future<S> findAsync<S>({Object? tag}) => _scope.findAsync<S>(tag: tag);

  /// Asynchronously resolves a dependency of type [S] (optionally matching
  /// [tag]), returning `null` when no registration exists.
  Future<S?> findOrNullAsync<S>({Object? tag}) =>
      _scope.findOrNullAsync<S>(tag: tag);

  /// Returns `true` if type [S] (with optional [tag]) is registered in the
  /// nearest widget scope or any ancestor scope.
  bool isRegistered<S>({Object? tag}) => _scope.isRegistered<S>(tag: tag);

  /// Returns `true` if type [S] (with optional [tag]) has already been
  /// instantiated in the nearest widget scope or any ancestor scope.
  bool isInstantiated<S>({Object? tag}) => _scope.isInstantiated<S>(tag: tag);

  /// Resolves a [LevitStore] recipe from the nearest scope.
  ///
  /// Inherits an ancestor store instance by default; pass `localOnly: true` to
  /// create or reuse an instance exclusively in the nearest scope.
  T findStore<T>(LevitStore<T> store, {Object? tag, bool localOnly = false}) =>
      store.findIn(_scope, tag: tag, localOnly: localOnly);

  /// Asynchronously resolves a [LevitAsyncStore] recipe from the nearest scope.
  ///
  /// Inherits an ancestor store instance by default; pass `localOnly: true` to
  /// create or reuse an instance exclusively in the nearest scope.
  Future<T> findAsyncStore<T>(
    LevitAsyncStore<T> store, {
    Object? tag,
    bool localOnly = false,
  }) => store.findIn(_scope, tag: tag, localOnly: localOnly);

  /// Inspects the nearest scope without resolving dependency values.
  LevitScopeDescription describe() => _scope.describe();

  /// Returns `true` if [store] (with optional [tag]) is registered in the
  /// nearest scope or an ancestor scope.
  bool isStoreRegistered<T>(LevitStore<T> store, {Object? tag}) =>
      store.isRegisteredIn(_scope, tag: tag);

  /// Returns `true` if [store] (with optional [tag]) is already instantiated in
  /// the nearest scope or an ancestor scope.
  bool isStoreInstantiated<T>(LevitStore<T> store, {Object? tag}) =>
      store.isInstantiatedIn(_scope, tag: tag);

  /// Returns `true` if async [store] (with optional [tag]) is registered in the
  /// nearest scope or an ancestor scope.
  bool isAsyncStoreRegistered<T>(LevitAsyncStore<T> store, {Object? tag}) =>
      store.isRegisteredIn(_scope, tag: tag);

  /// Returns `true` if async [store] (with optional [tag]) is already
  /// instantiated in the nearest scope or an ancestor scope.
  bool isAsyncStoreInstantiated<T>(LevitAsyncStore<T> store, {Object? tag}) =>
      store.isInstantiatedIn(_scope, tag: tag);

  /// Instantiates and registers a dependency.
  ///
  /// Registers within the nearest [LScope] if available; otherwise uses
  /// [Levit.currentScope].
  S put<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      scope.lazyPut<S>(
        builder,
        tag: tag,
        permanent: permanent,
        isFactory: isFactory,
      );
    } else {
      Levit.lazyPut<S>(
        builder,
        tag: tag,
        permanent: permanent,
        isFactory: isFactory,
      );
    }
  }

  /// Registers an asynchronous [builder] for lazy instantiation.
  Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.lazyPutAsync<S>(
        builder,
        tag: tag,
        permanent: permanent,
        isFactory: isFactory,
      );
    }
    return Levit.lazyPutAsync<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  /// Resolves the dependency, or registers it via [builder] if not found.
  S putOrFind<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      final instance = scope.findOrNull<S>(tag: tag);
      if (instance != null) return instance;
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }

    final instance = Levit.findOrNull<S>(tag: tag);
    if (instance != null) return instance;
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }
}

/// Extensions to access Levit dependency injection directly from [BuildContext].
///
/// {@category Flutter Widgets & Interop}
extension LevitBuildContextExtension on BuildContext {
  /// A [LevitContext] to interact with the nearest active [LevitScope].
  LevitContext get levit => LevitContext(this);
}
