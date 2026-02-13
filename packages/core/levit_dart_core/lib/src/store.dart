part of '../levit_dart_core.dart';

/// A bridge for interacting with the dependency injection system from a [LevitStore].
///
/// [LevitRef] allows stores to find other dependencies, register new ones,
/// and manage their own lifecycle via [onDispose]. It provides a scoped access
/// to the [Levit] tree without needing global static access.
abstract class LevitRef {
  /// The [LevitScope] that owns this store instance.
  LevitScope get scope;

  /// Finds an instance of type [S] in the current [scope].
  ///
  /// Uses optional [tag] to disambiguate registrations of the same type.
  ///
  /// Throws if no matching registration is available.
  S find<S>({String? tag});

  /// Asynchronously finds an instance of type [S] in the current [scope].
  ///
  /// Uses optional [tag] to disambiguate registrations of the same type.
  ///
  /// Throws if no matching registration is available.
  Future<S> findAsync<S>({String? tag});

  /// Finds the value of [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  ///
  /// Throws if the store cannot be created or resolved.
  R findStore<R>(LevitStore<R> store, {String? tag});

  /// Asynchronously finds the value of [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  ///
  /// Throws if the store cannot be created or resolved.
  Future<R> findStoreAsync<R>(LevitStore<R> store, {String? tag});

  /// Asynchronously finds and resolves the value of async [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  ///
  /// Throws if the store cannot be created or resolved.
  Future<R> findAsyncStore<R>(LevitAsyncStore<R> store, {String? tag});

  /// Registers a dependency in the current [scope].
  ///
  /// Creates the instance immediately with [builder].
  /// If [permanent] is `true`, deletion requires force semantics at scope level.
  S put<S>(S Function() builder, {String? tag, bool permanent = false});

  /// Lazily registers a dependency using [builder].
  ///
  /// If [isFactory] is `true`, [builder] runs on each resolution.
  /// If [permanent] is `true`, registration survives regular scope resets.
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false});

  /// Lazily registers an asynchronous dependency using [builder].
  ///
  /// Returns a trigger function that starts resolution when invoked.
  /// If [isFactory] is `true`, [builder] runs on each resolution.
  /// If [permanent] is `true`, registration survives regular scope resets.
  Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false});

  /// Registers [callback] to run when the store instance is disposed.
  void onDispose(void Function() callback);

  /// Registers [object] for automatic cleanup when the store closes.
  ///
  /// Returns [object].
  T autoDispose<T>(T object);
}

/// A portable container definition for managing reusable state.
///
/// [LevitStore] works like a "recipe" for creating state. Unlike [LevitController],
/// which you register manually, [LevitStore] is passed around by reference and
/// instantiated on demand.
///
/// When you call [find], it lazy-loads the instance in the current scope.
class LevitStore<T> {
  final T Function(LevitRef ref) _builder;

  /// Creates a scoped store definition from [builder].
  ///
  /// [builder] runs once per scope/tag instance when the store is first resolved.
  LevitStore(this._builder);

  late final String _defaultKey = 'ls_store_${_getStoreTag(this, null)}';

  /// Creates an asynchronous store definition from [builder].
  ///
  /// Returns a [LevitAsyncStore] that resolves to `T` instead of `Future<T>`.
  static LevitAsyncStore<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncStore<T>(builder);
  }

  /// Finds or creates the store instance within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances of the same store definition.
  ///
  /// Throws if [builder] throws while creating the store value.
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

  /// Asynchronously finds or creates the store instance within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances of the same store definition.
  ///
  /// Throws if [builder] throws while creating the store value.
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
  ///
  /// If [force] is `true`, removes even permanent registrations.
  ///
  /// Returns `true` when an instance registration was removed.
  bool deleteIn(LevitScope scope, {String? tag, bool force = false}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.delete<_LevitStoreInstance<T>>(tag: instanceKey, force: force);
  }

  /// Checks whether this store is registered in [scope].
  ///
  /// Returns `true` when registration metadata exists, even if not instantiated.
  bool isRegisteredIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isRegistered<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Checks whether this store is instantiated in [scope].
  ///
  /// Returns `true` when the store value has already been built.
  bool isInstantiatedIn(LevitScope scope, {String? tag}) {
    final instanceKey =
        tag != null ? 'ls_store_${_getStoreTag(this, tag)}' : _defaultKey;
    return scope.isInstantiated<_LevitStoreInstance<T>>(tag: instanceKey);
  }

  /// Finds the value of this store in the active scope.
  ///
  /// Uses optional [tag] to select an instance variant.
  ///
  /// Throws if no active scope is available or value creation fails.
  T find({String? tag}) => findIn(Ls.currentScope, tag: tag);

  /// Asynchronously finds the value of this store in the active scope.
  ///
  /// Uses optional [tag] to select an instance variant.
  ///
  /// Throws if no active scope is available or value creation fails.
  Future<T> findAsync({String? tag}) => findAsyncIn(Ls.currentScope, tag: tag);

  /// Removes this store from the active scope.
  ///
  /// If [force] is `true`, removes even permanent registrations.
  ///
  /// Returns `true` when a registration was removed.
  bool delete({String? tag, bool force = false}) =>
      deleteIn(Ls.currentScope, tag: tag, force: force);

  @override
  String toString() => 'LevitStore<$T>(id: $hashCode)';
}

/// A specialized store for asynchronous initialization.
///
/// Unlike `LevitStore<Future<T>>`, this type provides ergonomic lookup methods
/// that always resolve to `Future<T>` (single await).
class LevitAsyncStore<T> {
  final LevitStore<Future<T>> _inner;

  /// Creates an asynchronous store definition from [builder].
  ///
  /// [builder] is evaluated lazily per scope/tag instance.
  LevitAsyncStore(Future<T> Function(LevitRef ref) builder)
      : _inner = LevitStore<Future<T>>(builder);

  /// Finds or creates and resolves the store value within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances.
  ///
  /// Throws if initialization fails.
  Future<T> findIn(LevitScope scope, {String? tag}) {
    return _inner.findIn(scope, tag: tag);
  }

  /// Asynchronously finds or creates and resolves the store value within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances.
  ///
  /// Throws if initialization fails.
  Future<T> findAsyncIn(LevitScope scope, {String? tag}) async {
    final future = await _inner.findAsyncIn(scope, tag: tag);
    return await future;
  }

  /// Finds and resolves the store value in the active scope.
  ///
  /// Throws if no active scope is available or initialization fails.
  Future<T> find({String? tag}) => findIn(Ls.currentScope, tag: tag);

  /// Asynchronously finds and resolves the store value in the active scope.
  ///
  /// Throws if no active scope is available or initialization fails.
  Future<T> findAsync({String? tag}) => findAsyncIn(Ls.currentScope, tag: tag);

  /// Deletes the store instance from [scope].
  bool deleteIn(LevitScope scope, {String? tag, bool force = false}) {
    return _inner.deleteIn(scope, tag: tag, force: force);
  }

  /// Checks if the store is registered in [scope].
  bool isRegisteredIn(LevitScope scope, {String? tag}) {
    return _inner.isRegisteredIn(scope, tag: tag);
  }

  /// Checks if the store is instantiated in [scope].
  bool isInstantiatedIn(LevitScope scope, {String? tag}) {
    return _inner.isInstantiatedIn(scope, tag: tag);
  }

  /// Removes this store from the active scope.
  bool delete({String? tag, bool force = false}) =>
      deleteIn(Ls.currentScope, tag: tag, force: force);

  @override
  String toString() => 'LevitAsyncStore<$T>(id: $hashCode)';
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
  S find<S>({String? tag}) {
    return scope.find<S>(tag: tag);
  }

  @override
  Future<S> findAsync<S>({String? tag}) async {
    return await scope.findAsync<S>(tag: tag);
  }

  @override
  R findStore<R>(LevitStore<R> store, {String? tag}) {
    return store.findIn(scope, tag: tag);
  }

  @override
  Future<R> findStoreAsync<R>(LevitStore<R> store, {String? tag}) {
    return store.findAsyncIn(scope, tag: tag);
  }

  @override
  Future<R> findAsyncStore<R>(LevitAsyncStore<R> store, {String? tag}) {
    return store.findIn(scope, tag: tag);
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
