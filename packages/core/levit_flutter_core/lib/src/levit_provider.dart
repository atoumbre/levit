part of '../levit_flutter_core.dart';

/// Gateway for finding dependencies from [BuildContext].
///
/// Proxies calls to the nearest [LScope] found in the widget tree.
/// If no local scope is found, it falls back to the global [Levit] scope.
class LevitProvider {
  final BuildContext _context;

  LevitProvider(this._context);

  /// Resolves a dependency of type [S] or identified by [key] or [tag].
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.findIn(scope, tag: tag) as S;
    }
    if (key is LevitAsyncStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.findIn(scope, tag: tag) as S;
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.find<S>(tag: tag);
    }
    return Levit.find<S>(tag: tag);
  }

  /// Resolves a dependency, or null if not found.
  S? findOrNull<S>({dynamic key, String? tag}) {
    try {
      if (key is LevitStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        return key.findIn(scope, tag: tag) as S?;
      }
      if (key is LevitAsyncStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        return key.findIn(scope, tag: tag) as S?;
      }
      final scope = _ScopeProvider.of(_context);
      if (scope != null) {
        return scope.findOrNull<S>(tag: tag);
      }
      return Levit.findOrNull<S>(tag: tag);
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously resolves a dependency of type [S] or identified by [key] or [tag].
  Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      final result = await key.findAsyncIn(scope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    if (key is LevitAsyncStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return await key.findAsyncIn(scope, tag: tag) as S;
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return await scope.findAsync<S>(tag: tag);
    }
    return await Levit.findAsync<S>(tag: tag);
  }

  /// Asynchronously resolves a dependency, or null if not found.
  Future<S?> findOrNullAsync<S>({dynamic key, String? tag}) async {
    try {
      if (key is LevitStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        final result = await key.findAsyncIn(scope, tag: tag);
        if (result is Future) return await result as S?;
        return result as S?;
      }
      if (key is LevitAsyncStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        return await key.findAsyncIn(scope, tag: tag) as S?;
      }
      final scope = _ScopeProvider.of(_context);
      if (scope != null) {
        return await scope.findOrNullAsync<S>(tag: tag);
      }
      return await Levit.findOrNullAsync<S>(tag: tag);
    } catch (_) {
      return null;
    }
  }

  /// Whether type [S] is registered in the current or any parent scope.
  bool isRegistered<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isRegisteredIn(scope, tag: tag);
    }
    if (key is LevitAsyncStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isRegisteredIn(scope, tag: tag);
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isRegistered<S>(tag: tag);
    }
    return Levit.isRegistered<S>(tag: tag);
  }

  /// Whether type [S] has already been instantiated.
  bool isInstantiated<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isInstantiatedIn(scope, tag: tag);
    }
    if (key is LevitAsyncStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isInstantiatedIn(scope, tag: tag);
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isInstantiated<S>(tag: tag);
    }
    return Levit.isInstantiated<S>(tag: tag);
  }

  /// Instantiates and registers a dependency.
  ///
  /// Registers within the nearest [LScope] if available; otherwise uses global [Levit].
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  void lazyPut<S>(
    S Function() builder, {
    String? tag,
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
    String? tag,
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
  S putOrFind<S>(S Function() builder, {String? tag, bool permanent = false}) {
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
extension LevitProviderExtension on BuildContext {
  /// A [LevitProvider] to interact with the nearest active [LevitScope].
  LevitProvider get levit => LevitProvider(this);
}
