part of 'dart_core_library.dart';

/// A bridge for interacting with the dependency injection system from a [LevitStore].
///
/// [LevitRef] allows stores to find other dependencies, register new ones,
/// and manage their own lifecycle via [onDispose]. It provides scoped access
/// to the [Levit] tree without needing global static access.
///
/// {@category Controllers & Stores}
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
/// pass `localOnly: true` to create or reuse an instance in the target scope.
/// Builders run once per successful scope/tag initialization, so return
/// reactive objects for state that changes and register owned resources with
/// `ref.own(...)`.
///
/// ```dart
/// final counterStore = LevitStore<LxInt>((ref) {
///   return ref.own(0.lx.named('counter'));
/// });
///
/// final count = counterStore.find();
/// count.increment();
/// ```
///
/// {@category Controllers & Stores}
class LevitStore<T> {
  final T Function(LevitRef ref) _builder;

  /// Creates a scoped store definition from the given builder function.
  ///
  /// The builder runs once per scope/tag instance on first successful
  /// resolution; if it throws synchronously, subsequent resolutions retry it.
  LevitStore(this._builder);

  late final _LevitStoreKey _defaultKey = _LevitStoreKey(this, null);

  /// Overrides this recipe in a receiving scope, before its first local lookup.
  ///
  /// Override builders follow the same ownership rules as ordinary store
  /// builders. Installing the returned [LevitOverride] throws a [StateError] if
  /// this store (for the matching [tag]) has already been resolved locally in
  /// the target scope.
  LevitOverride overrideWith(T Function(LevitRef ref) builder, {Object? tag}) {
    final key = tag == null ? _defaultKey : _LevitStoreKey(this, tag);
    return _LevitStoreOverride<T>._((scope) {
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
  /// Returns a [LevitAsyncStore] typed over `T` (rather than `Future<T>`) for
  /// async lookup and widget APIs such as `findAsyncStore` and `LAsyncView.store`.
  static LevitAsyncStore<T> async<T>(Future<T> Function(LevitRef ref) builder) {
    return LevitAsyncStore<T>(builder);
  }

  /// Finds or creates the store instance within [scope].
  ///
  /// Uses optional [tag] to isolate independent instances of the same store definition.
  /// With [localOnly], reuse or create only in [scope] without inheriting from ancestors.
  ///
  /// Throws any error thrown while building the store value.
  T findIn(LevitScope scope, {Object? tag, bool localOnly = false}) {
    final instanceKey = tag != null ? _LevitStoreKey(this, tag) : _defaultKey;

    final instance =
        (localOnly &&
                !scope.isRegisteredLocally<_LevitStoreInstance>(
                  tag: instanceKey,
                )
            ? null
            : scope.findOrNull<_LevitStoreInstance>(tag: instanceKey)) ??
        scope.put<_LevitStoreInstance>(
          () => _LevitStoreInstance(_builder),
          tag: instanceKey,
        );

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

  /// Finds the value of this store in [Levit.currentScope].
  ///
  /// Uses optional [tag] to select an instance variant. Inherits an ancestor
  /// instance by default unless [localOnly] is `true`.
  ///
  /// Throws any error thrown while creating the store value.
  T find({Object? tag, bool localOnly = false}) =>
      findIn(Ls.currentScope, tag: tag, localOnly: localOnly);

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

/// A specialized store recipe for asynchronous initialization.
///
/// Carries the resolved value type `T` directly (rather than `Future<T>`) so
/// async APIs such as `findAsyncStore`, `overrideAsyncStore`, and async view
/// widgets can expose `T` cleanly while resolving via `Future<T>`.
///
/// ```dart
/// final configStore = LevitStore.async<AppConfig>((ref) async {
///   final client = ref.find<HttpClient>();
///   return await client.fetchConfig();
/// });
///
/// final config = await configStore.find();
/// ```
///
/// {@category Controllers & Stores}
class LevitAsyncStore<T> {
  final LevitStore<Future<T>> _inner;

  /// Creates an asynchronous store definition from [builder].
  ///
  /// [builder] is evaluated lazily per scope/tag instance.
  LevitAsyncStore(Future<T> Function(LevitRef ref) builder)
    : _inner = LevitStore<Future<T>>(builder);

  /// Provides an asynchronous replacement in the receiving scope.
  LevitOverride overrideWith(
    Future<T> Function(LevitRef ref) builder, {
    Object? tag,
  }) {
    final override = _inner.overrideWith(builder, tag: tag);
    return _LevitStoreOverride<T>._(override.installIn);
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

  /// Finds and resolves the store value in [Levit.currentScope].
  ///
  /// Inherits an ancestor instance by default unless [localOnly] is `true`.
  /// Throws if initialization fails.
  Future<T> find({Object? tag, bool localOnly = false}) =>
      findIn(Ls.currentScope, tag: tag, localOnly: localOnly);

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

/// The actual holder of a [LevitStore] instance within a [LevitScope].
class _LevitStoreInstance extends LevitController implements LevitRef {
  final dynamic Function(LevitRef ref) _builder;

  dynamic _value;
  bool _builderRun = false;

  _LevitStoreInstance(this._builder);

  @override
  LevitScope get scope => super.scope!;

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
      if (_value is Future && !scope.isClosing && !scope.isDisposed) {
        unawaited(
          scope.trackInitialization(
            (_value as Future).then<void>(
              (_) {},
              onError: (Object _, StackTrace __) {},
            ),
          ),
        );
      }
      _builderRun = true;
    }
    return _value;
  }

  @override
  S find<S>({Object? tag}) {
    return scope.find<S>(tag: tag);
  }

  @override
  Future<S> findAsync<S>({Object? tag}) {
    return scope.findAsync<S>(tag: tag);
  }

  @override
  R findStore<R>(LevitStore<R> store, {Object? tag, bool localOnly = false}) {
    return store.findIn(scope, tag: tag, localOnly: localOnly);
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
///
/// {@category Controllers & Stores}
abstract interface class LevitOverride {
  /// Installs this override into [scope].
  ///
  /// Throws a [StateError] if the target store has already been resolved
  /// locally in [scope].
  void installIn(LevitScope scope);
}

final class _LevitStoreOverride<T> implements LevitOverride {
  _LevitStoreOverride._(this._install);
  final void Function(LevitScope) _install;
  @override
  void installIn(LevitScope scope) => _install(scope);
}

/// Extension methods for installing [LevitStore] and [LevitAsyncStore]
/// overrides into any [LevitScope].
///
/// Production scopes and test scopes share this same explicit override
/// mechanism.
///
/// ```dart
/// final testScope = Levit.createScope('test');
/// testScope.applyOverrides([
///   counterStore.overrideWith((ref) => ref.own(42.lx)),
/// ]);
/// ```
///
/// {@category Controllers & Stores}
extension LevitScopeStoreOverrides on LevitScope {
  /// Installs every override in [overrides] into this scope in iteration order.
  ///
  /// Throws a [StateError] if any overridden store has already been resolved
  /// locally in this scope.
  void applyOverrides(Iterable<LevitOverride> overrides) {
    for (final override in overrides) {
      override.installIn(this);
    }
  }

  /// Overrides [store] locally in this scope with [builder] (optionally scoped
  /// to [tag]).
  ///
  /// Must be called before [store] is first resolved locally in this scope;
  /// otherwise throws a [StateError].
  void overrideStore<T>(
    LevitStore<T> store,
    T Function(LevitRef) builder, {
    Object? tag,
  }) => store.overrideWith(builder, tag: tag).installIn(this);

  /// Overrides async [store] locally in this scope with [builder] (optionally
  /// scoped to [tag]).
  ///
  /// Must be called before [store] is first resolved locally in this scope;
  /// otherwise throws a [StateError].
  void overrideAsyncStore<T>(
    LevitAsyncStore<T> store,
    Future<T> Function(LevitRef) builder, {
    Object? tag,
  }) => store.overrideWith(builder, tag: tag).installIn(this);
}

final class _LevitStoreKey {
  static final int _variantSalt = math.Random.secure().nextInt(0x7fffffff);

  _LevitStoreKey(this.definition, this.variant)
    : _hashCode = Object.hash(identityHashCode(definition), variant);

  final Object definition;
  final Object? variant;
  final int _hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _LevitStoreKey &&
          identical(definition, other.definition) &&
          variant == other.variant);

  @override
  int get hashCode => _hashCode;

  @override
  String toString() {
    final variantLabel = variant == null
        ? 'default'
        : Object.hash(_variantSalt, variant).toUnsigned(32).toRadixString(16);
    return 'store#${identityHashCode(definition)}:$variantLabel';
  }
}
