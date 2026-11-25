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
  S find<S>({Object? tag});

  /// Asynchronously finds an instance of type [S] in the current [scope].
  ///
  /// Uses optional [tag] to disambiguate registrations of the same type.
  ///
  /// Throws if no matching registration is available.
  Future<S> findAsync<S>({Object? tag});

  /// Finds the value of [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  /// With [localOnly], ancestor instances are ignored.
  ///
  /// Throws if the store cannot be created or resolved.
  R findStore<R>(LevitStore<R> store, {Object? tag, bool localOnly = false});

  /// Asynchronously finds the value of [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  /// With [localOnly], ancestor instances are ignored.
  ///
  /// Throws if the store cannot be created or resolved.
  Future<R> findStoreAsync<R>(
    LevitStore<R> store, {
    Object? tag,
    bool localOnly = false,
  });

  /// Asynchronously finds and resolves the value of async [store] within the current [scope].
  ///
  /// Uses optional [tag] to select a store instance variant.
  /// With [localOnly], ancestor instances are ignored.
  ///
  /// Throws if the store cannot be created or resolved.
  Future<R> findAsyncStore<R>(
    LevitAsyncStore<R> store, {
    Object? tag,
    bool localOnly = false,
  });

  /// Registers a dependency in the current [scope].
  ///
  /// Creates the instance immediately with [builder].
  /// If [permanent] is `true`, deletion requires force semantics at scope level.
  S put<S>(S Function() builder, {Object? tag, bool permanent = false});

  /// Lazily registers a dependency using [builder].
  ///
  /// If [isFactory] is `true`, [builder] runs on each resolution.
  /// If [permanent] is `true`, registration survives regular scope resets.
  void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  });

  /// Lazily registers an asynchronous dependency using [builder].
  ///
  /// Returns a trigger function that starts resolution when invoked.
  /// If [isFactory] is `true`, [builder] runs on each resolution.
  /// If [permanent] is `true`, registration survives regular scope resets.
  Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  });

  /// Binds [Alias] to an existing local singleton [Concrete].
  void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  });

  /// Registers [callback] to run when the store instance is disposed.
  void onDispose(FutureOr<void> Function() callback);

  /// Registers [object] for automatic cleanup when the store closes.
  T own<T>(T object, {FutureOr<void> Function(T object)? dispose});
}

/// A portable container definition for managing reusable state.
///
/// [LevitStore] works like a "recipe" for creating state. Unlike [LevitController],
/// which you register manually, [LevitStore] is passed around by reference and
/// instantiated on demand. Lookups inherit an ancestor instance by default;
/// pass `localOnly: true` to create or reuse an instance in the current scope.
/// Builders run once, so return reactive objects for state that changes.
///
/// When you call [find], it lazy-loads the instance in the current scope.
class LevitStore<T> {
  final T Function(LevitRef ref) _builder;

  /// Creates a scoped store definition from [builder].
  ///
  /// [builder] runs once per scope/tag instance when the store is first resolved.
  LevitStore(this._builder);

  late final _LevitStoreKey _defaultKey = _LevitStoreKey(this, null);

  /// Overrides this recipe in a receiving scope, before its first lookup there.
  /// Override builders use the same ownership rules as ordinary store builders.
  LevitStoreOverride<T> overrideWith(
    T Function(LevitRef ref) builder, {
    Object? tag,
  }) {
    final key = tag == null ? _defaultKey : _LevitStoreKey(this, tag);
    return LevitStoreOverride<T>._((scope) {
      if (scope.isRegisteredLocally<_LevitStoreInstance>(tag: key)) {
        throw StateError(
          'Install a store override before its first local resolution.',
        );
      }
      scope.lazyPut(() => _LevitStoreInstance(builder), tag: key);
    });
  }

  /// Creates an asynchronous store definition from [builder].
  ///
  /// Returns a [LevitAsyncStore] that resolves to `T` instead of `Future<T>`.
  static LevitAsyncStore<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncStore<T>(builder);
  }

  /// Finds or creates the store instance within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances of the same store definition.
  /// With [localOnly], reuse or create only in [scope].
  ///
  /// Throws if [builder] throws while creating the store value.
  T findIn(LevitScope scope, {Object? tag, bool localOnly = false}) {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;

    var instance =
        localOnly &&
            !scope.isRegisteredLocally<_LevitStoreInstance>(tag: instanceKey)
        ? null
        : scope.findOrNull<_LevitStoreInstance>(tag: instanceKey);

    if (instance == null) {
      scope.put(() => _LevitStoreInstance(_builder), tag: instanceKey);
      instance = scope.find<_LevitStoreInstance>(tag: instanceKey);
    }

    return instance.value as T;
  }

  /// Asynchronously finds or creates the store instance within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances of the same store definition.
  /// With [localOnly], reuse or create only in [scope].
  ///
  /// Throws if [builder] throws while creating the store value.
  Future<T> findAsyncIn(
    LevitScope scope, {
    Object? tag,
    bool localOnly = false,
  }) async {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;

    var instance =
        localOnly &&
            !scope.isRegisteredLocally<_LevitStoreInstance>(tag: instanceKey)
        ? null
        : await scope.findOrNullAsync<_LevitStoreInstance>(tag: instanceKey);

    if (instance == null) {
      if (!scope.isRegisteredLocally<_LevitStoreInstance>(tag: instanceKey)) {
        scope.lazyPut(() => _LevitStoreInstance(_builder), tag: instanceKey);
      }
      instance = await scope.findAsync<_LevitStoreInstance>(tag: instanceKey);
    }

    return instance.value as T;
  }

  /// Deletes the store instance from [scope].
  ///
  /// If [force] is `true`, removes even permanent registrations.
  ///
  /// Returns `true` when an instance registration was removed.
  Future<bool> deleteIn(LevitScope scope, {Object? tag, bool force = false}) {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;
    return scope.delete<_LevitStoreInstance>(tag: instanceKey, force: force);
  }

  /// Checks whether this store is registered in [scope].
  ///
  /// Returns `true` when registration metadata exists, even if not instantiated.
  bool isRegisteredIn(LevitScope scope, {Object? tag}) {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;
    return scope.isRegistered<_LevitStoreInstance>(tag: instanceKey);
  }

  /// Checks whether this store is instantiated in [scope].
  ///
  /// Returns `true` when the store value has already been built.
  bool isInstantiatedIn(LevitScope scope, {Object? tag}) {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;
    return scope.isInstantiated<_LevitStoreInstance>(tag: instanceKey);
  }

  /// Finds the value of this store in the active scope.
  ///
  /// Uses optional [tag] to select an instance variant.
  ///
  /// Throws if no active scope is available or value creation fails.
  T find({Object? tag, bool localOnly = false}) =>
      findIn(Ls.currentScope, tag: tag, localOnly: localOnly);

  /// Asynchronously finds the value of this store in the active scope.
  ///
  /// Uses optional [tag] to select an instance variant.
  ///
  /// Throws if no active scope is available or value creation fails.
  Future<T> findAsync({Object? tag, bool localOnly = false}) =>
      findAsyncIn(Ls.currentScope, tag: tag, localOnly: localOnly);

  /// Removes this store from the active scope.
  ///
  /// If [force] is `true`, removes even permanent registrations.
  ///
  /// Returns `true` when a registration was removed.
  Future<bool> delete({Object? tag, bool force = false}) =>
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

  /// Provides an asynchronous replacement in the receiving scope.
  LevitStoreOverride<T> overrideWith(
    Future<T> Function(LevitRef ref) builder, {
    Object? tag,
  }) {
    final override = _inner.overrideWith(builder, tag: tag);
    return LevitStoreOverride<T>._(override.installIn);
  }

  /// Finds or creates and resolves the store value within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances.
  /// With [localOnly], reuse or create only in [scope].
  ///
  /// Throws if initialization fails.
  Future<T> findIn(LevitScope scope, {Object? tag, bool localOnly = false}) {
    return _inner.findIn(scope, tag: tag, localOnly: localOnly);
  }

  /// Asynchronously finds or creates and resolves the store value within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances.
  /// With [localOnly], reuse or create only in [scope].
  ///
  /// Throws if initialization fails.
  Future<T> findAsyncIn(
    LevitScope scope, {
    Object? tag,
    bool localOnly = false,
  }) async {
    final future = await _inner.findAsyncIn(
      scope,
      tag: tag,
      localOnly: localOnly,
    );
    return await future;
  }

  /// Finds and resolves the store value in the active scope.
  ///
  /// Throws if no active scope is available or initialization fails.
  Future<T> find({Object? tag, bool localOnly = false}) =>
      findIn(Ls.currentScope, tag: tag, localOnly: localOnly);

  /// Asynchronously finds and resolves the store value in the active scope.
  ///
  /// Throws if no active scope is available or initialization fails.
  Future<T> findAsync({Object? tag, bool localOnly = false}) =>
      findAsyncIn(Ls.currentScope, tag: tag, localOnly: localOnly);

  /// Deletes the store instance from [scope].
  Future<bool> deleteIn(LevitScope scope, {Object? tag, bool force = false}) {
    return _inner.deleteIn(scope, tag: tag, force: force);
  }

  /// Checks if the store is registered in [scope].
  bool isRegisteredIn(LevitScope scope, {Object? tag}) {
    return _inner.isRegisteredIn(scope, tag: tag);
  }

  /// Checks if the store is instantiated in [scope].
  bool isInstantiatedIn(LevitScope scope, {Object? tag}) {
    return _inner.isInstantiatedIn(scope, tag: tag);
  }

  /// Removes this store from the active scope.
  Future<bool> delete({Object? tag, bool force = false}) =>
      deleteIn(Ls.currentScope, tag: tag, force: force);

  @override
  String toString() => 'LevitAsyncStore<$T>(id: $hashCode)';
}

/// Returns [scope] or throws when a [LevitRef] is used before scope attachment.
@visibleForTesting
LevitScope requireStoreRefScope(LevitScope? scope) {
  if (scope == null) {
    throw StateError(
      'Store ref has no owning scope. Resolve the store via Levit.put/find '
      'or LevitStore.findIn before using LevitRef APIs.',
    );
  }
  return scope;
}

/// The actual holder of a [LevitStore] instance within a [LevitScope].
class _LevitStoreInstance extends LevitController implements LevitRef {
  final dynamic Function(LevitRef ref) _builder;

  dynamic _value;
  bool _builderRun = false;

  _LevitStoreInstance(this._builder);

  @override
  LevitScope get scope => requireStoreRefScope(super.scope);

  dynamic get value {
    if (!_builderRun) {
      // Capture builder-created reactives so store-owned state is auto-disposed.
      // `_builderRun` stays false on failure, allowing a retry on next read.
      _value = _AutoLinkScope.runCaptured(
        () => _runInitialization(() => _builder(this)),
        (captured, _) {
          for (final reactive in captured) {
            _adoptCaptured(reactive);
          }
        },
        ownerId: ownerPath,
        onSettled: _trackCapturedInitialization,
      );
      _builderRun = true;
    }
    return _value;
  }

  @override
  S find<S>({Object? tag}) {
    return scope.find<S>(tag: tag);
  }

  @override
  Future<S> findAsync<S>({Object? tag}) async {
    return await scope.findAsync<S>(tag: tag);
  }

  @override
  R findStore<R>(LevitStore<R> store, {Object? tag, bool localOnly = false}) {
    return store.findIn(scope, tag: tag, localOnly: localOnly);
  }

  @override
  Future<R> findStoreAsync<R>(
    LevitStore<R> store, {
    Object? tag,
    bool localOnly = false,
  }) {
    return store.findAsyncIn(scope, tag: tag, localOnly: localOnly);
  }

  @override
  Future<R> findAsyncStore<R>(
    LevitAsyncStore<R> store, {
    Object? tag,
    bool localOnly = false,
  }) {
    return store.findIn(scope, tag: tag, localOnly: localOnly);
  }

  @override
  S put<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    return scope.put<S>(builder, tag: tag, permanent: permanent);
  }

  @override
  void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    scope.lazyPut<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  @override
  Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    return scope.lazyPutAsync<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  @override
  void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  }) {
    scope.bindExisting<Alias, Concrete>(sourceTag: sourceTag, tag: tag);
  }

  @override
  void onDispose(FutureOr<void> Function() callback) {
    own(callback);
  }
}

/// A typed, reusable store override. Installation never modifies an ancestor.
abstract interface class LevitOverride {
  void installIn(LevitScope scope);
}

final class LevitStoreOverride<T> implements LevitOverride {
  LevitStoreOverride._(this._install);
  final void Function(LevitScope) _install;
  @override
  void installIn(LevitScope scope) => _install(scope);
}

/// Production and test scopes share the same explicit override mechanism.
extension LevitScopeStoreOverrides on LevitScope {
  void applyOverrides(Iterable<LevitOverride> overrides) {
    for (final override in overrides) {
      override.installIn(this);
    }
  }

  void overrideStore<T>(
    LevitStore<T> store,
    T Function(LevitRef) builder, {
    Object? tag,
  }) => store.overrideWith(builder, tag: tag).installIn(this);

  void overrideAsyncStore<T>(
    LevitAsyncStore<T> store,
    Future<T> Function(LevitRef) builder, {
    Object? tag,
  }) => store.overrideWith(builder, tag: tag).installIn(this);
}

final class _LevitStoreKey {
  const _LevitStoreKey(this.definition, this.variant);
  final Object definition;
  final Object? variant;
  @override
  bool operator ==(Object other) =>
      other is _LevitStoreKey &&
      identical(definition, other.definition) &&
      variant == other.variant;
  @override
  int get hashCode => Object.hash(identityHashCode(definition), variant);
  @override
  String toString() =>
      'store#${identityHashCode(definition)}:${variant == null ? 'default' : variant.hashCode}';
}
