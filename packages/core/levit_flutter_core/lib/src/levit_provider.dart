part of '../levit_flutter_core.dart';

/// Gateway for finding dependencies from [BuildContext].
///
/// Proxies calls to the nearest [LScope] found in the widget tree.
/// If no local scope is found, it falls back to the global [Levit] scope.
class LevitContext {
  final BuildContext _context;

  LevitContext(this._context);

  LevitScope get _scope => _ScopeProvider.of(_context) ?? Levit.currentScope;

  /// Resolves a typed dependency through the nearest widget scope.
  S find<S>({Object? tag}) => _scope.find<S>(tag: tag);

  /// Returns null only when no registration exists. Builder errors propagate.
  S? findOrNull<S>({Object? tag}) => _scope.findOrNull<S>(tag: tag);

  Future<S> findAsync<S>({Object? tag}) => _scope.findAsync<S>(tag: tag);
  Future<S?> findOrNullAsync<S>({Object? tag}) =>
      _scope.findOrNullAsync<S>(tag: tag);
  bool isRegistered<S>({Object? tag}) => _scope.isRegistered<S>(tag: tag);
  bool isInstantiated<S>({Object? tag}) => _scope.isInstantiated<S>(tag: tag);

  /// Resolves a store recipe, optionally requiring locally owned state.
  T findStore<T>(LevitStore<T> store, {Object? tag, bool localOnly = false}) =>
      store.findIn(_scope, tag: tag, localOnly: localOnly);

  Future<T> findAsyncStore<T>(
    LevitAsyncStore<T> store, {
    Object? tag,
    bool localOnly = false,
  }) => store.findIn(_scope, tag: tag, localOnly: localOnly);

  /// Inspects the nearest scope without resolving dependency values.
  LevitScopeDescription describe() => _scope.describe();

  bool isStoreRegistered<T>(LevitStore<T> store, {Object? tag}) =>
      store.isRegisteredIn(_scope, tag: tag);
  bool isStoreInstantiated<T>(LevitStore<T> store, {Object? tag}) =>
      store.isInstantiatedIn(_scope, tag: tag);
  bool isAsyncStoreRegistered<T>(LevitAsyncStore<T> store, {Object? tag}) =>
      store.isRegisteredIn(_scope, tag: tag);
  bool isAsyncStoreInstantiated<T>(LevitAsyncStore<T> store, {Object? tag}) =>
      store.isInstantiatedIn(_scope, tag: tag);

  /// Instantiates and registers a dependency.
  ///
  /// Registers within the nearest [LScope] if available; otherwise uses global [Levit].
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
extension LevitBuildContextExtension on BuildContext {
  /// A [LevitContext] to interact with the nearest active [LevitScope].
  LevitContext get levit => LevitContext(this);
}
