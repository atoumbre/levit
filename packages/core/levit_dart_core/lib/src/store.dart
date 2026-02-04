part of '../levit_dart_core.dart';

/// A bridge for interacting with the dependency injection system from a [LevitStore].
///
/// [LevitRef] allows stores to find other dependencies, register new ones,
/// and manage their own lifecycle via [onDispose].
abstract class LevitRef {
  /// The [LevitScope] that owns this store instance.
  LevitScope get scope;

  /// Finds an instance of type [S] in the current scope.
  S find<S>({dynamic key, String? tag});

  /// Asynchronously finds an instance of type [S].
  Future<S> findAsync<S>({dynamic key, String? tag});

  /// Registers a dependency in the current scope.
  S put<S>(S Function() builder, {String? tag, bool permanent = false});

  /// Lazily registers a dependency.
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false});

  /// Lazily registers an asynchronous dependency.
  Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false});

  /// Registers a callback to run when the store is disposed.
  void onDispose(void Function() callback);

  /// Registers [object] for automatic cleanup.
  ///
  /// Returns [object].
  T autoDispose<T>(T object);
}

/// A portable container definition.
///
/// [LevitStore] works like a "recipe" for creating state. Unlike [LevitController],
/// which you register manually, [LevitStore] is passed around by reference.
///
/// When you call `store.find()`, it lazy-loads the instance in the current scope.
///
/// Example:
/// ```dart
/// final counterStore = LevitStore((ref) {
///   final count = 0.lx;
///   return count;
/// });
///
/// // Usage
/// final count = counterStore.find();
/// ```
class LevitStore<T> {
  final T Function(LevitRef ref) _builder;

  LevitStore(this._builder);

  late final String _defaultKey = 'ls_store_${_getStoreTag(this, null)}';

  /// Creates an asynchronous [LevitStore] definition.
  static LevitAsyncStore<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncStore<T>(builder);
  }

  /// Finds (or creates) the store instance within [scope].
  T findIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;

    var instance = scope.findOrNull<_LevitStoreInstance<T>>(tag: instanceKey);

    if (instance == null) {
      scope.put(() => _LevitStoreInstance<T>(this), tag: instanceKey);
      instance = scope.find<_LevitStoreInstance<T>>(tag: instanceKey);
    }

    return instance.value;
  }

  /// Asynchronously finds (or creates) the store instance within [scope].
  Future<T> findAsyncIn(LevitScope scope, {String? tag}) async {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;

    var instance =
        await scope.findOrNullAsync<_LevitStoreInstance<T>>(tag: instanceKey);

    if (instance == null) {
      scope.lazyPut(() => _LevitStoreInstance<T>(this), tag: instanceKey);
      instance =
          await scope.findAsync<_LevitStoreInstance<T>>(tag: instanceKey);
    }

    return instance.value;
  }

  /// Deletes the store instance from [scope].
  bool deleteIn(LevitScope scope, {String? tag, bool force = false}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.delete<_LevitStoreInstance<T>>(tag: instanceKey, force: force);
  }

  /// Checks if the store is registered in [scope].
  bool isRegisteredIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isRegistered<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Checks if the store is instantiated in [scope].
  bool isInstantiatedIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isInstantiated<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Finds the value of this store in the active scope.
  T find({String? tag}) => Levit.find<T>(key: this, tag: tag);

  /// Asynchronously finds the value of this store in the active scope.
  Future<T> findAsync({String? tag}) => Levit.findAsync<T>(key: this, tag: tag);

  /// Removes this store from the active scope.
  bool delete({String? tag, bool force = false}) =>
      Levit.delete(key: this, tag: tag, force: force);

  @override
  String toString() => 'LevitStore<$T>(id: $hashCode)';
}

/// A specialized [LevitStore] for asynchronous initialization.
class LevitAsyncStore<T> extends LevitStore<Future<T>> {
  LevitAsyncStore(super.builder);
}

/// The actual holder of a [LevitStore] instance within a [LevitScope].
class _LevitStoreInstance<T> extends LevitController implements LevitRef {
  final LevitStore<T> definition;

  T? _value;
  bool _builderRun = false;

  _LevitStoreInstance(this.definition);

  @override
  LevitScope get scope => super.scope!;

  T get value {
    if (!_builderRun) {
      // Use "Restored Zone Capture" for initialization.
      // This ensures that any `0.lx` created in the builder is captured
      // and disposed when the store closes, even if it's an orphan.
      //
      // If `definition._builder` throws, `_builderRun` will remain false,
      // and the error will be re-thrown. The store will attempt to re-initialize
      // on the next access.
      _value = _AutoLinkScope.runCaptured(
        () => definition._builder(this),
        (captured, _) {
          for (final reactive in captured) {
            autoDispose(reactive);
          }
        },
        ownerId: ownerPath,
      );
      _builderRun = true;
    }
    return _value as T;
  }

  @override
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.findIn(scope, tag: tag) as S;
    }
    return scope.find<S>(tag: tag);
  }

  @override
  Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final result = await key.findAsyncIn(scope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    return await scope.findAsync<S>(tag: tag);
  }

  @override
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return scope.put<S>(builder, tag: tag, permanent: permanent);
  }

  @override
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    scope.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  @override
  Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return scope.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  @override
  void onDispose(void Function() callback) {
    autoDispose(callback);
  }
}

/// Helper to tag stores.
String _getStoreTag(LevitStore provider, String? tag) {
  if (tag != null) return tag;
  return 'lxs_${provider.hashCode}';
}
