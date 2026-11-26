part of 'scope_library.dart';

/// An interface for objects that participate in the [LevitScope] lifecycle.
///
/// Extend or implement this class to receive callbacks for initialization,
/// scope attachment, and disposal. This ensures deterministic cleanup when the
/// owning scope is disposed.
///
/// ```dart
/// class MyService extends LevitScopeDisposable {
///   @override
///   void onInit() {
///     // Initialize internal state.
///   }
///
///   @override
///   Future<void> onClose() async {
///     // Release resources asynchronously.
///   }
/// }
/// ```
///
/// {@category Scopes & DI}
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
  FutureOr<void> onClose() {}
}

/// A resource with an explicit, optionally asynchronous disposal operation.
///
/// Unlike [LevitScopeDisposable], this contract has no initialization hooks.
/// A directly registered instance implementing this interface is owned by its
/// registration scope and disposed when that registration is removed.
///
/// {@category Scopes & DI}
abstract interface class LevitDisposable {
  /// Releases resources held by this object.
  FutureOr<void> dispose();
}

/// A boundary that rejects cleanup from work that it is currently draining.
///
/// {@category SPI}
abstract interface class LevitExecutionBoundary {
  /// Throws a [StateError] if called synchronously from inside work currently
  /// owned or drained by this boundary.
  void assertCanDispose();
}

/// Owned asynchronous work that must settle before dependencies are released.
/// Cancellation is a request; [drain] observes actual completion.
///
/// {@category SPI}
abstract interface class LevitDrainable {
  /// Stops admission and requests cooperative cancellation immediately.
  void requestCancel();

  /// Waits for active work, including its finally blocks.
  Future<void> drain();
}

/// One failure captured while a scope or resource owner was being disposed.
///
/// {@category Scopes & DI}
final class LevitDisposalFailure {
  /// The resource whose cleanup failed.
  final Object resource;

  /// The error thrown by the resource.
  final Object error;

  /// The associated stack trace.
  final StackTrace stackTrace;

  /// Creates a disposal failure record.
  const LevitDisposalFailure({
    required this.resource,
    required this.error,
    required this.stackTrace,
  });

  @override
  String toString() => 'LevitDisposalFailure(${resource.runtimeType}: $error)';
}

/// Aggregate error thrown after best-effort disposal has finished.
///
/// Cleanup always continues after an individual failure. Callers receive this
/// exception only after every selected resource has been given a chance to
/// close.
///
/// {@category Scopes & DI}
final class LevitDisposalException implements Exception {
  /// All failures in deterministic disposal order.
  final List<LevitDisposalFailure> failures;

  /// Creates an aggregate disposal error.
  LevitDisposalException(Iterable<LevitDisposalFailure> failures)
    : failures = List<LevitDisposalFailure>.unmodifiable(failures);

  /// Flattens nested owner failures and removes duplicate reports of the same
  /// resource/error pair collected during cancellation, draining and release.
  LevitDisposalException.aggregate(Iterable<LevitDisposalFailure> failures)
    : failures = List<LevitDisposalFailure>.unmodifiable(
        _flattenFailures(failures),
      );

  static List<LevitDisposalFailure> _flattenFailures(
    Iterable<LevitDisposalFailure> input,
  ) {
    final result = <LevitDisposalFailure>[];
    void add(LevitDisposalFailure failure) {
      final error = failure.error;
      if (error is LevitDisposalException) {
        for (final child in error.failures) {
          add(child);
        }
      } else if (!result.any(
        (item) =>
            identical(item.resource, failure.resource) &&
            identical(item.error, failure.error),
      )) {
        result.add(failure);
      }
    }

    for (final failure in input) {
      add(failure);
    }
    return result;
  }

  @override
  String toString() =>
      'LevitDisposalException(${failures.length} cleanup failure'
      '${failures.length == 1 ? '' : 's'})';
}

/// Metadata container for a dependency registered within a [LevitScope].
///
/// This class tracks the lifecycle state, creation strategy, and persistence
/// settings for a specific registration.
///
/// {@category Scopes & DI}
class LevitDependency<S> {
  /// The resolved instance, or `null` if not yet instantiated.
  S? instance;

  /// The synchronous builder function for lazy or factory instantiation.
  final S Function()? builder;

  /// The asynchronous builder function for async instantiation.
  final Future<S> Function()? asyncBuilder;

  /// Whether the registration persists across a non-forced [LevitScope.reset].
  ///
  /// [LevitScope.dispose] always force-clears permanent registrations, so
  /// permanent dependencies do not survive disposed scopes (including unmounted
  /// UI scopes and test scopes). Prefer `permanent: true` on root or long-lived
  /// scopes; on short-lived scopes it does not extend lifetime past disposal.
  final bool permanent;

  /// Whether the instance creation is deferred until the first lookup.
  final bool isLazy;

  /// Whether a new instance is created for every lookup.
  final bool isFactory;

  Set<Object>? _factoryStorage;
  Set<Object> get _factoryInstances => _factoryStorage ?? const {};
  Set<Future<void>>? _pendingStorage;
  Set<Future<void>> get _pendingFactories => _pendingStorage ?? const {};
  List<LevitDisposalFailure>? _initializationFailureStorage;
  List<LevitDisposalFailure> get _initializationFailures =>
      _initializationFailureStorage ?? const [];
  List<LevitDisposalFailure> get _mutableInitializationFailures =>
      _initializationFailureStorage ??= [];
  List<LevitDisposalFailure>? _releasedFactoryFailureStorage;
  List<LevitDisposalFailure> get _releasedFactoryFailures =>
      _releasedFactoryFailureStorage ?? const [];
  List<LevitDisposalFailure> get _mutableReleasedFactoryFailures =>
      _releasedFactoryFailureStorage ??= [];
  late final Set<Future<void>> _factoryReleases = {};
  late final _releasingFactoryInstances = HashSet<Object>.identity();
  LevitScope? _scope;

  /// Includes middleware initialization/capture cleanup in this registration's
  /// lifetime, including work adopted while an earlier operation drains.
  /// Failures are collected after all tracked work settles and are reported by
  /// awaited registration disposal.
  void trackInitialization(Future<void> operation) {
    late final Future<void> tracked;
    tracked = operation
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _mutableInitializationFailures.add(
              LevitDisposalFailure(
                resource: this,
                error: error,
                stackTrace: stack,
              ),
            );
          },
        )
        .whenComplete(() {
          _pendingStorage?.remove(tracked);
          _scope?._notifyScopeProgress();
        });
    (_pendingStorage ??= {}).add(tracked);
    _scope?._notifyScopeProgress();
  }

  Completer<void>? _removalComplete;
  bool _removed = false;
  _LevitScopeKey? _retiringKey;
  Future<void>? _cleanupFuture;
  bool get _hasFactoryWork =>
      _factoryInstances.isNotEmpty || _pendingFactories.isNotEmpty;

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
class _LevitScopeKey {
  static final Map<Type, String> _debugTypeCache = {};

  final Type type;
  final Object? tag;

  const _LevitScopeKey(this.type, this.tag);

  static _LevitScopeKey of<S>({Object? tag}) => _LevitScopeKey(S, tag);

  String get debugString {
    final typeString = _debugTypeCache[type] ??= type.toString();
    if (tag == null) return typeString;
    // Preserve historical format: Type_tag
    return '${typeString}_$tag';
  }

  @override
  bool operator ==(Object other) =>
      other is _LevitScopeKey && other.type == type && other.tag == tag;

  @override
  int get hashCode => tag == null ? type.hashCode : Object.hash(type, tag);
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
/// When a scope is disposed via `await scope.dispose()`:
/// * Owned child scopes are disposed first in reverse creation order (LIFO).
/// * All locally owned dependencies — including [LevitScopeDisposable]
///   (`onClose`), [LevitDisposable] (`dispose`), and disposable factory results
///   — are cancelled, drained, and closed in reverse registration order,
///   including `permanent: true` registrations.
/// * Multiple cleanup errors are collected and rethrown together as a
///   [LevitDisposalException].
/// * The scope becomes unusable and should be discarded.
///
/// {@category Scopes & DI}
class LevitScope implements LevitDisposable, LevitExecutionBoundary {
  /// Internal counter for unique scope IDs.
  static int _nextId = 0;

  /// The unique identifier for this scope.
  final int id;

  /// A descriptive name for debugging.
  final String name;

  /// The parent scope, or `null` if this is the root scope.
  final LevitScope? _parentScope;

  /// The local registry of dependencies (Key -> Metadata).
  final Map<_LevitScopeKey, LevitDependency> _registry = {};

  /// Fast-path registry for tag-less lookups (Type -> Metadata).
  final Map<Type, LevitDependency> _typeRegistry = {};

  /// Ultra-fast instance cache for tag-less singletons.
  final Map<Type, dynamic> _instanceCache = {};

  /// Non-owning local aliases (alias key -> canonical local key).
  Map<_LevitScopeKey, _LevitScopeKey>? _aliasStorage;
  Map<_LevitScopeKey, _LevitScopeKey> get _aliases => _aliasStorage ?? const {};

  /// Reverse alias index used to invalidate aliases with their canonical key.
  Map<_LevitScopeKey, Set<_LevitScopeKey>>? _aliasesByCanonical;

  Map<_LevitScopeKey, LevitDependency>? _retiringStorage;

  static const Object _notFound = Object();

  Future<void>? _disposeFuture;
  Completer<void>? _disposedCompleter;
  Set<LevitScope>? _ownedChildrenStorage;
  Set<LevitScope> get _ownedChildren => _ownedChildrenStorage ?? const {};
  Map<Object, int>? _opaqueTagIds;
  List<LevitDisposalFailure>? _cancellationFailures;
  bool _isClosing = false;
  bool _isDisposed = false;

  /// Whether terminal scope disposal has started.
  bool get isClosing => _isClosing;

  /// Whether terminal scope disposal has completed.
  bool get isDisposed => _isDisposed;

  /// Completes when terminal disposal finishes, including failed cleanup.
  /// Await [dispose] to receive aggregated cleanup errors.
  Future<void> get disposed {
    final completed = _disposedCompleter ??= Completer<void>();
    if (_isDisposed && !completed.isCompleted) completed.complete();
    return completed.future;
  }

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
  /// same [tag] already exists, await [delete] before registering its replacement.
  ///
  /// ```dart
  /// scope.put(() => AuthService());
  /// ```
  ///
  /// Use [permanent] to survive a *non-forced* [reset] only.
  /// [dispose] always force-clears permanent registrations so they do not leak
  /// across disposed scopes. Prefer `permanent: true` on root or long-lived scopes.
  ///
  /// Returns the created instance.
  S put<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    _ensureUsable();
    final key = _getKey<S>(tag);
    final keyString = key.debugString;
    final existing = _registry[key];
    if ((_retiringStorage?.containsKey(key) ?? false) ||
        (existing != null && existing.isFactory && existing._hasFactoryWork)) {
      throw StateError('Await delete<$S> before replacing "$keyString".');
    }

    if (existing != null || (_aliasStorage?.containsKey(key) ?? false)) {
      throw StateError(
        'LevitScope($name): "$keyString" is already registered. '
        'Await delete<$S>(tag: ${tag == null ? 'null' : "'$tag'"}, force: true) '
        'before registering a replacement.',
      );
    }

    final info = LevitDependency<S>(permanent: permanent);

    // Instance creation happens before registration so middleware sees final metadata.
    final created = _createInstance<S>(builder, keyString, info);

    if (_isClosing ||
        _isDisposed ||
        (_retiringStorage?.containsKey(key) ?? false) ||
        _registry.containsKey(key) ||
        (_aliasStorage?.containsKey(key) ?? false)) {
      if (created != null) {
        final cleanup = _disposeInstance(created);
        if (cleanup is Future<void>) {
          if (!_isClosing && !_isDisposed) {
            unawaited(trackInitialization(cleanup));
          } else {
            unawaited(cleanup);
          }
        }
      }
      if (_isClosing || _isDisposed) {
        throw StateError('LevitScope($name) was disposed during put<$S>().');
      }
      throw StateError(
        'LevitScope($name): "$keyString" was registered or retired during put<$S>().',
      );
    }

    info.instance = created;

    _registerBinding(key, keyString, info, 'put', tag: tag);

    _initializeInstance(info.instance, keyString, info);

    return info.instance as S;
  }

  /// Registers a dependency to be lazily instantiated.
  ///
  /// The [builder] is only executed when the dependency is first requested via [find].
  ///
  /// If [isFactory] is `true`, a new instance will be created for *every* request.
  /// Disposable results belong to this registering scope, even when resolved
  /// through a child. They close in reverse creation order when removed.
  /// Otherwise (default), the instance is cached and treated as a singleton within this scope.
  ///
  /// Use [permanent] to survive a *non-forced* [reset] only.
  /// [dispose] always force-clears permanent registrations. Prefer
  /// `permanent: true` on root or long-lived scopes.
  void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    _ensureUsable();
    final key = _getKey<S>(tag);
    final keyString = key.debugString;
    final existing = _registry[key];
    if ((_retiringStorage?.containsKey(key) ?? false) ||
        (existing != null &&
            (existing._hasFactoryWork ||
                existing._initializationFailures.isNotEmpty)) ||
        (_pendingInit?.containsKey(key) ?? false) ||
        (isFactory && existing?.isInstantiated == true)) {
      throw StateError('Await delete<$S> before replacing "$keyString".');
    }

    if (_aliasStorage?.containsKey(key) ?? false) {
      throw StateError(
        'LevitScope($name): "$keyString" is already registered as an alias.',
      );
    }
    if (!isFactory && existing != null && existing.isInstantiated) {
      return;
    }

    final info = LevitDependency<S>(
      builder: builder,
      permanent: permanent,
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
  /// This scope owns disposable results and awaits pending creation on teardown.
  /// Otherwise, the result is cached.
  ///
  /// Use [permanent] to survive a *non-forced* [reset] only.
  /// [dispose] always force-clears permanent registrations. Prefer
  /// `permanent: true` on root or long-lived scopes.
  ///
  /// Returns a function that allows retrieving the dependency (shortcut for `findAsync`).
  Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    _ensureUsable();
    final key = _getKey<S>(tag);
    final keyString = key.debugString;
    final existing = _registry[key];
    if ((_retiringStorage?.containsKey(key) ?? false) ||
        (existing != null &&
            (existing._hasFactoryWork ||
                existing._initializationFailures.isNotEmpty)) ||
        (_pendingInit?.containsKey(key) ?? false) ||
        (isFactory && existing?.isInstantiated == true)) {
      throw StateError('Await delete<$S> before replacing "$keyString".');
    }

    if (_aliasStorage?.containsKey(key) ?? false) {
      throw StateError(
        'LevitScope($name): "$keyString" is already registered as an alias.',
      );
    }
    if (!isFactory && existing != null && existing.isInstantiated) {
      return () => findAsync<S>(tag: tag);
    }

    final info = LevitDependency<S>(
      asyncBuilder: builder,
      permanent: permanent,
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

  /// Binds [Alias] to an existing local singleton registration of [Concrete].
  ///
  /// The alias is non-owning: resolving it returns the canonical instance,
  /// deleting it does not dispose that instance, and disposing the canonical
  /// registration removes all of its aliases before disposing it once.
  ///
  /// Aliases are intentionally local and cannot target factory registrations.
  void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  }) {
    _ensureUsable();

    final aliasKey = _getKey<Alias>(tag);
    final canonicalKey = _getKey<Concrete>(sourceTag);
    final canonical = _registry[canonicalKey];

    if (canonical == null) {
      throw StateError(
        'LevitScope($name): Cannot bind alias "${aliasKey.debugString}" '
        'because local source "${canonicalKey.debugString}" is not registered.',
      );
    }
    if (canonical.isFactory) {
      throw StateError(
        'LevitScope($name): Factory registration '
        '"${canonicalKey.debugString}" cannot be aliased.',
      );
    }
    if (aliasKey == canonicalKey) {
      throw ArgumentError(
        'Alias and canonical registration must use different keys.',
      );
    }
    if (_registry.containsKey(aliasKey) || _aliases.containsKey(aliasKey)) {
      throw StateError(
        'LevitScope($name): Alias key "${aliasKey.debugString}" is already '
        'registered.',
      );
    }

    (_aliasStorage ??= {})[aliasKey] = canonicalKey;
    ((_aliasesByCanonical ??= {})[canonicalKey] ??= <_LevitScopeKey>{}).add(
      aliasKey,
    );
    _invalidateLookupCaches(aliasKey);
    _notifyRegister(aliasKey.debugString, canonical, 'bindExisting');
  }

  void _registerBinding<S>(
    _LevitScopeKey key,
    String keyString,
    LevitDependency<S> info,
    String source, {
    Object? tag,
  }) {
    _registry[key] = info;

    // Tag-less bindings are mirrored in type registries for O(1) lookups.
    if (tag == null) {
      _typeRegistry[S] = info;
      final instance = info.instance;
      if (instance != null && !info.isFactory) {
        _instanceCache[S] = instance;
      } else {
        _instanceCache.remove(S);
      }
    }

    _notifyRegister(keyString, info, source);
  }

  @pragma('vm:prefer-inline')
  Object? _lookupSync<S>(Object? tag) {
    if (tag == null) {
      LevitScope? scope = this;
      while (scope != null) {
        scope._ensureUsable();
        final cached = scope._instanceCache[S];
        if (cached != null) return cached;

        final info = scope._typeRegistry[S];
        if (info != null) {
          final instance = info.instance;
          if (instance != null && !info.isFactory) {
            scope._instanceCache[S] = instance;
            return instance;
          }
          final result = scope._findLocal<S>(
            info as LevitDependency<S>,
            _LevitScopeKey.of<S>().debugString,
            null,
          );
          if (!info.isFactory && info.instance != null) {
            scope._instanceCache[S] = info.instance;
          }
          return result;
        }

        final aliases = scope._aliasStorage;
        if (aliases != null && aliases.isNotEmpty) {
          final aliasKey = _LevitScopeKey.of<S>();
          final canonicalKey = aliases[aliasKey];
          if (canonicalKey != null) {
            final result = scope._findAliasLocal<S>(
              aliasKey: aliasKey,
              canonicalKey: canonicalKey,
            );
            scope._instanceCache[S] = result;
            return result;
          }
        }

        scope = scope._parentScope;
      }
      return _notFound;
    }

    // Tagged lookups use composite key registries and defer debugString until needed.
    final key = _getKey<S>(tag);
    LevitScope? scope = this;
    while (scope != null) {
      scope._ensureUsable();
      final info = scope._registry[key];
      if (info != null) {
        final instance = info.instance;
        if (instance != null && !info.isFactory) {
          return instance;
        }
        return scope._findLocal<S>(
          info as LevitDependency<S>,
          key.debugString,
          tag,
        );
      }

      final aliases = scope._aliasStorage;
      if (aliases != null && aliases.isNotEmpty) {
        final canonicalKey = aliases[key];
        if (canonicalKey != null) {
          return scope._findAliasLocal<S>(
            aliasKey: key,
            canonicalKey: canonicalKey,
          );
        }
      }

      scope = scope._parentScope;
    }
    return _notFound;
  }

  /// Finds and returns a registered instance of type [S].
  ///
  /// This method performs a hierarchical lookup:
  /// 1.  **Local Check**: Checks the current scope.
  /// 2.  **Parent Check**: Walks ancestor scopes iteratively.
  ///
  /// If the dependency is found but not yet instantiated (lazy), it will be created.
  ///
  /// Throws an [Exception] if [S] is not registered in this scope or any ancestor.
  S find<S>({Object? tag}) {
    final result = _lookupSync<S>(tag);
    if (!identical(result, _notFound)) return result as S;
    throw Exception(
      tag == null
          ? 'LevitScope($name): Type "$S" is not registered.\n'
                'Not found in scope or any parent.'
          : 'LevitScope($name): Type "$S" with tag "$tag" is not registered.\n'
                'Not found in scope or any parent.',
    );
  }

  /// Finds and returns a registered instance of type [S], or `null` if not found.
  ///
  /// Mirrors the behavior of [find] but returns `null` instead of throwing an exception
  /// if the dependency is missing.
  S? findOrNull<S>({Object? tag}) {
    final result = _lookupSync<S>(tag);
    return identical(result, _notFound) ? null : result as S?;
  }

  Future<Object?> _lookupAsync<S>(Object? tag) async {
    final key = _getKey<S>(tag);
    LevitScope? scope = this;
    while (scope != null) {
      scope._ensureUsable();
      final info = scope._registry[key];
      if (info != null) {
        if (info.isInstantiated && !info.isFactory) {
          return info.instance;
        }
        return scope._findLocalAsync<S>(
          info as LevitDependency<S>,
          key,
          key.debugString,
          tag,
        );
      }

      final aliases = scope._aliasStorage;
      if (aliases != null && aliases.isNotEmpty) {
        final canonicalKey = aliases[key];
        if (canonicalKey != null) {
          return scope._findAliasLocalAsync<S>(
            aliasKey: key,
            canonicalKey: canonicalKey,
          );
        }
      }

      scope = scope._parentScope;
    }
    return _notFound;
  }

  /// Finds and returns an asynchronously registered instance of type [S].
  ///
  /// Use this for dependencies registered via [lazyPutAsync].
  ///
  /// Throws an [Exception] if [S] is not registered.
  Future<S> findAsync<S>({Object? tag}) async {
    final result = await _lookupAsync<S>(tag);
    if (!identical(result, _notFound)) return result as S;
    throw Exception(
      'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is not registered.\n'
      'Not found in scope or any parent.',
    );
  }

  /// Asynchronously finds an instance of type [S], or returns `null` if not found.
  Future<S?> findOrNullAsync<S>({Object? tag}) async {
    final result = await _lookupAsync<S>(tag);
    return identical(result, _notFound) ? null : result as S?;
  }

  // In-flight async singleton initializations keyed by dependency key.
  Map<_LevitScopeKey, Future<dynamic>>? _pendingInit;
  Set<Future<void>>? _pendingInitializationStorage;
  Set<Future<void>> get _pendingInitializations =>
      _pendingInitializationStorage ?? const {};

  /// Waits for currently tracked initialization, including work added by it.
  /// Ongoing services are not stopped. Await [dispose] to check cleanup failures.
  Future<void> waitForInitialization() async {
    while (true) {
      final pending = <Future<void>>[
        ..._pendingInitializations,
        for (final info in {..._registry.values, ...?_retiringStorage?.values})
          ...info._pendingFactories,
      ];
      if (pending.isEmpty) return;
      await Future.wait(pending);
    }
  }

  /// Takes an immutable metadata snapshot. Dependency values and raw tags are
  /// excluded; tagged registrations expose only an opaque tag identifier.
  LevitScopeDescription describe() {
    final ancestors = <LevitScopeIdentity>[];
    for (
      var parent = _parentScope;
      parent != null;
      parent = parent._parentScope
    ) {
      ancestors.add(LevitScopeIdentity(parent.id, parent.name));
    }
    String keyId(_LevitScopeKey key) {
      final tag = key.tag;
      if (tag == null) return '${key.type}#default';
      final ids = _opaqueTagIds ??= <Object, int>{};
      final opaqueId = ids.putIfAbsent(tag, () => ids.length + 1);
      return '${key.type}#tag$opaqueId';
    }

    return LevitScopeDescription(
      id: id,
      name: name,
      isClosing: isClosing,
      isDisposed: isDisposed,
      ancestry: ancestors,
      ownedChildren: _ownedChildren.map(
        (child) => LevitScopeIdentity(child.id, child.name),
      ),
      pendingInitializations: _pendingInitializations.length,
      registrations: [
        for (final entry in {..._registry, ...?_retiringStorage}.entries)
          LevitRegistrationDescription(
            key: keyId(entry.key),
            type: entry.key.type.toString(),
            isFactory: entry.value.isFactory,
            isAsync: entry.value.isAsync,
            isLazy: entry.value.isLazy,
            permanent: entry.value.permanent,
            isInstantiated: entry.value.isInstantiated,
            isClosing: isClosing || entry.value._removed,
            pendingInitializations: entry.value._pendingFactories.length,
            ownedInstances:
                entry.value._factoryInstances.length +
                (entry.value.isInstantiated ? 1 : 0),
          ),
        for (final alias in _aliases.entries)
          LevitRegistrationDescription(
            key: keyId(alias.key),
            type: alias.key.type.toString(),
            aliasOf: keyId(alias.value),
          ),
      ],
    );
  }

  /// Registers initialization performed outside a DI builder (for example a
  /// widget scope factory). Its completion is included in scope disposal.
  /// The caller remains responsible for observing the operation's error.
  /// Prefer [runInitialization] for work that has not started: it also guards
  /// against initialization attempting to await its own scope's disposal.
  Future<T> trackInitialization<T>(Future<T> operation) {
    _ensureUsable();
    late final Future<void> settled;
    settled = operation
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() {
          _pendingInitializationStorage?.remove(settled);
          _notifyScopeProgress();
        });
    (_pendingInitializationStorage ??= {}).add(settled);
    _notifyScopeProgress();
    return operation;
  }

  /// Admits initialization before invoking [initialize], including synchronous
  /// reentrant replacement. Its scope cannot be disposed from that execution
  /// until the returned operation settles. Cancellation may still be requested.
  FutureOr<T> runInitialization<T>(FutureOr<T> Function() initialize) {
    _ensureUsable();
    final completed = Completer<void>();
    unawaited(trackInitialization(completed.future));
    try {
      final result = _guardInitialization(initialize);
      if (result is Future<T>) return result.whenComplete(completed.complete);
      completed.complete();
      return result;
    } catch (_) {
      completed.complete();
      rethrow;
    }
  }

  static final Object _initializationZone = Object();

  R _guardInitialization<R>(
    R Function() initialize, {
    LevitDependency? registration,
  }) {
    final execution = _ScopeInitialization(
      this,
      registration,
      Zone.current[_initializationZone] as _ScopeInitialization?,
    );
    try {
      final result = runZoned(
        initialize,
        zoneValues: {_initializationZone: execution},
      );
      if (result is Future) {
        unawaited(
          result.then<void>(
            (_) {
              execution.active = false;
            },
            onError: (Object _, StackTrace __) {
              execution.active = false;
            },
          ),
        );
      } else {
        execution.active = false;
      }
      return result;
    } catch (_) {
      execution.active = false;
      rethrow;
    }
  }

  Future<S> _findLocalAsync<S>(
    LevitDependency<S> info,
    _LevitScopeKey key,
    String keyString,
    Object? tag,
  ) async {
    if (info.isInstantiated) {
      return info.instance as S;
    }

    // Factories always create a fresh instance.
    if (info.isFactory && info.isAsync) {
      return _createFactoryAsync(info, keyString);
    }

    // `findAsync` supports sync factories for API parity.
    if (info.isFactory && info.builder != null) {
      final instance = _createInstance<S>(info.builder!, keyString, info);
      _trackFactoryInstance(info, instance);
      _initializeInstance(instance, keyString, info);
      _notifyResolve(keyString, info, 'findAsync');
      return instance;
    }

    // Concurrent async resolves share one initializer future per key.
    if (info.isLazy && info.isAsync) {
      if (_pendingInit?[key] case final pending?) {
        return await pending as S;
      }

      final finished = Completer<void>();
      (info._pendingStorage ??= {}).add(finished.future);
      _notifyScopeProgress();
      late final Future<S> future;
      future = (() async {
        try {
          final instance = await _createInstanceAsync<S>(
            info.asyncBuilder!,
            keyString,
            info,
          );
          info.instance = instance;
          if (info._removed || _isClosing || _isDisposed) {
            info._pendingStorage?.remove(finished.future);
            _notifyScopeProgress();
            finished.complete();
            throw StateError(
              'LevitScope($name): Dependency "$keyString" was disposed while initializing.',
            );
          }
          _initializeInstance(instance, keyString, info);
          _notifyResolve(keyString, info, 'findAsync');
          return instance;
        } finally {
          info._pendingStorage?.remove(finished.future);
          _notifyScopeProgress();
          if (!finished.isCompleted) finished.complete();
          if (identical(_pendingInit?[key], future)) _pendingInit?.remove(key);
        }
      })();
      (_pendingInit ??= {})[key] = future;
      return future;
    }

    // `findAsync` can resolve sync registrations when no async builder exists.
    return _findLocal<S>(info, keyString, tag);
  }

  S _findAliasLocal<S>({
    required _LevitScopeKey aliasKey,
    required _LevitScopeKey canonicalKey,
  }) {
    final info = _registry[canonicalKey]!;
    if (info.isAsync && !info.isInstantiated) {
      throw StateError(
        'LevitScope($name): Alias "${aliasKey.debugString}" targets an '
        'asynchronous registration. Use findAsync().',
      );
    }

    final instance = _findLocal<dynamic>(
      info,
      canonicalKey.debugString,
      canonicalKey.tag,
    );
    _notifyResolve(aliasKey.debugString, info, 'findAlias');
    return instance as S;
  }

  Future<S> _findAliasLocalAsync<S>({
    required _LevitScopeKey aliasKey,
    required _LevitScopeKey canonicalKey,
  }) async {
    final info = _registry[canonicalKey]!;

    final instance = await _findLocalAsync<dynamic>(
      info,
      canonicalKey,
      canonicalKey.debugString,
      canonicalKey.tag,
    );
    _notifyResolve(aliasKey.debugString, info, 'findAliasAsync');
    return instance as S;
  }

  S _findLocal<S>(LevitDependency<S> info, String key, Object? tag) {
    if (info.isAsync && !info.isInstantiated) {
      throw StateError(
        'LevitScope($name): Type "$S"${tag != null ? ' with tag "$tag"' : ''} is registered as async and not yet instantiated. Use findAsync() to initialize it.',
      );
    }

    // Factories bypass cached instance storage.
    if (info.isFactory && info.builder != null) {
      final instance = _createInstance<S>(info.builder!, key, info);
      _trackFactoryInstance(info, instance);
      _initializeInstance(instance, key, info);
      _notifyResolve(key, info, 'find');
      return instance;
    }

    // Lazy singleton instantiates once and is reused afterward.
    if (info.isLazy && !info.isInstantiated) {
      info.instance = _createInstance<S>(info.builder!, key, info);
      _initializeInstance(info.instance, key, info);
      _notifyResolve(key, info, 'find');
    }

    return info.instance as S;
  }

  void _trackFactoryInstance(LevitDependency info, Object? instance) {
    if (instance is LevitScopeDisposable || instance is LevitDisposable) {
      (info._factoryStorage ??= LinkedHashSet<Object>.identity()).add(
        instance!,
      );
    }
  }

  Future<S> _createFactoryAsync<S>(LevitDependency<S> info, String key) async {
    final finished = Completer<void>();
    (info._pendingStorage ??= {}).add(finished.future);
    _notifyScopeProgress();
    try {
      final instance = await _createInstanceAsync<S>(
        info.asyncBuilder!,
        key,
        info,
      );
      _trackFactoryInstance(info, instance);
      if (info._removed || _isClosing || _isDisposed) {
        // Creation has finished. Teardown can now dispose every result in
        // reverse creation order, including concurrent late completions.
        info._pendingStorage?.remove(finished.future);
        _notifyScopeProgress();
        finished.complete();
        throw StateError(
          'LevitScope($name): Factory "$key" was removed while initializing.',
        );
      }
      _initializeInstance(instance, key, info);
      _notifyResolve(key, info, 'findAsync');
      return instance;
    } finally {
      info._pendingStorage?.remove(finished.future);
      _notifyScopeProgress();
      if (!finished.isCompleted) finished.complete();
    }
  }

  S _createInstance<S>(S Function() builder, String key, LevitDependency info) {
    final wrappedBuilder = _applyCreateInstanceHooks<S>(builder, key, info);
    return _guardInitialization(wrappedBuilder, registration: info);
  }

  Future<S> _createInstanceAsync<S>(
    Future<S> Function() builder,
    String key,
    LevitDependency info,
  ) async {
    final wrappedBuilder = _applyCreateInstanceHooks<Future<S>>(
      builder,
      key,
      info,
    );
    return _guardInitialization(wrappedBuilder, registration: info);
  }

  void _initializeInstance(dynamic instance, String key, LevitDependency info) {
    if (instance is LevitScopeDisposable) {
      _applyInitHooks(instance, instance.onInit, key, info);
      instance.didAttachToScope(this, key: key);
    }
  }

  /// Returns `true` if type [S] is registered in this scope (parent scopes are ignored).
  bool isRegisteredLocally<S>({Object? tag}) {
    if (tag == null) {
      if (_typeRegistry.containsKey(S)) return true;
      final aliases = _aliasStorage;
      return aliases != null && aliases.containsKey(_LevitScopeKey.of<S>());
    }
    final key = _getKey<S>(tag);
    return _registry.containsKey(key) ||
        (_aliasStorage?.containsKey(key) ?? false);
  }

  /// Returns `true` if type [S] is registered in this scope or any ancestor.
  bool isRegistered<S>({Object? tag}) {
    LevitScope? scope = this;
    while (scope != null) {
      if (scope.isRegisteredLocally<S>(tag: tag)) return true;
      scope = scope._parentScope;
    }
    return false;
  }

  /// Returns `true` if the dependency [S] has already been instantiated.
  ///
  /// This checks if the lazy builder has executed or if the instance was put directly.
  bool isInstantiated<S>({Object? tag}) {
    final key = _getKey<S>(tag);
    LevitScope? scope = this;
    while (scope != null) {
      final local = scope._registry[key];
      if (local != null) {
        return local.isInstantiated;
      }
      final canonicalKey = scope._aliasStorage?[key];
      if (canonicalKey != null) {
        return scope._registry[canonicalKey]?.isInstantiated ?? false;
      }
      scope = scope._parentScope;
    }
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
  Future<bool> delete<S>({Object? tag, bool force = false}) async {
    _ensureUsable();
    final key = _getKey<S>(tag);
    final keyString = key.debugString;

    if (_aliases.containsKey(key)) {
      final canonicalKey = _aliases[key]!;
      final info = _registry[canonicalKey];
      _removeAlias(key);
      if (info != null) {
        final failures = _notifyDelete(keyString, info, 'deleteAlias');
        if (failures != null) throw LevitDisposalException.aggregate(failures);
      }
      return true;
    }

    final info = _registry[key];
    if (info == null) return false;

    if (info.permanent && !force) return false;

    _assertRegistrationCanDispose(info);
    final failures = _notifyDelete(keyString, info, 'delete');
    if (failures != null) info._mutableInitializationFailures.addAll(failures);
    _removeCanonicalBinding(key);

    await _disposeRegistrations([info]);
    return true;
  }

  /// Releases a disposable factory result early, without removing its recipe.
  /// Returns `false` when [instance] is not owned by the resolved factory.
  /// Waits for admitted registration initialization, then cancels, drains and
  /// closes the instance. Releasing work cannot await its own disposal.
  /// Failures also remain observable through registration/scope disposal.
  Future<bool> releaseFactoryInstance<S>(S instance, {Object? tag}) async {
    _ensureUsable();
    final info = _registry[_getKey<S>(tag)];
    if (info == null) {
      return await _parentScope?.releaseFactoryInstance<S>(
            instance,
            tag: tag,
          ) ??
          false;
    }
    if (!info.isFactory ||
        !info._factoryInstances.contains(instance) ||
        info._releasingFactoryInstances.contains(instance)) {
      return false;
    }
    _assertNotInitializing(info);
    if (instance is LevitExecutionBoundary) instance.assertCanDispose();
    info._releasingFactoryInstances.add(instance as Object);
    final finished = Completer<void>();
    (info._pendingStorage ??= {}).add(finished.future);
    info._factoryReleases.add(finished.future);
    _notifyScopeProgress();
    try {
      while (true) {
        final initializing = info._pendingFactories
            .where((work) => !info._factoryReleases.contains(work))
            .toList();
        if (initializing.isEmpty) break;
        await Future.wait(initializing);
      }
      final released = LevitDependency(instance: instance)
        .._mutableInitializationFailures.addAll(info._initializationFailures);
      await _disposeRegistrations([
        released,
      ], includeScopeInitialization: false);
      return true;
    } catch (error, stackTrace) {
      info._mutableReleasedFactoryFailures.add(
        LevitDisposalFailure(
          resource: instance,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      rethrow;
    } finally {
      info._factoryStorage?.remove(instance);
      info._releasingFactoryInstances.remove(instance);
      info._factoryReleases.remove(finished.future);
      info._pendingStorage?.remove(finished.future);
      _notifyScopeProgress();
      finished.complete();
    }
  }

  /// Disposes all dependencies registered in this scope.
  ///
  /// Dependencies marked as `permanent` are preserved unless [force] is `true`.
  Future<void> reset({bool force = false}) async {
    _ensureUsable();
    final entriesToRemove = <MapEntry<_LevitScopeKey, LevitDependency>>[];

    for (final entry in _registry.entries.toList(growable: false)) {
      final info = entry.value;

      if (info.permanent && !force) continue;

      _assertRegistrationCanDispose(info);
      entriesToRemove.add(entry);
    }

    for (final entry in entriesToRemove) {
      final failures = _notifyDelete(
        entry.key.debugString,
        entry.value,
        'reset',
      );
      if (failures != null) {
        entry.value._mutableInitializationFailures.addAll(failures);
      }
      _removeCanonicalBinding(entry.key);
    }

    if (force) {
      // Force reset also drops all lookup caches.
      _typeRegistry.clear();
      _instanceCache.clear();
    }

    await _disposeRegistrations(
      entriesToRemove.map((entry) => entry.value).toList().reversed,
    );
  }

  void _assertNotInitializing(LevitDependency info) {
    for (
      var execution =
          Zone.current[_initializationZone] as _ScopeInitialization?;
      execution != null;
      execution = execution.parent
    ) {
      if (execution.active && identical(execution.registration, info)) {
        throw StateError('Initialization cannot release its own registration.');
      }
    }
  }

  void _assertRegistrationCanDispose(LevitDependency info) {
    _assertNotInitializing(info);
    _assertResourcesCanDispose(info);
  }

  static void _assertResourcesCanDispose(LevitDependency info) {
    final instance = info.instance;
    if (instance is LevitExecutionBoundary) instance.assertCanDispose();
    for (final resource in info._factoryStorage?.toList() ?? const <Object>[]) {
      if (resource is LevitExecutionBoundary) resource.assertCanDispose();
    }
  }

  /// Rejects disposal from this scope's initialization or owned tracked work,
  /// including registrations already removed from lookup while cleanup drains.
  @override
  void assertCanDispose() {
    for (
      var execution =
          Zone.current[_initializationZone] as _ScopeInitialization?;
      execution != null;
      execution = execution.parent
    ) {
      if (execution.active && identical(execution.scope, this)) {
        throw StateError(
          'Initialization cannot dispose its own scope; request cancellation instead.',
        );
      }
    }
    for (final child in _ownedChildren) {
      child.assertCanDispose();
    }
    for (final info in _registry.values) {
      _assertResourcesCanDispose(info);
    }
    // Registrations leave lookup before their work drains. Their execution
    // boundaries must still reject a task awaiting its own closing scope.
    final retiring = _retiringStorage;
    if (retiring != null && retiring.isNotEmpty) {
      for (final info in retiring.values) {
        _assertResourcesCanDispose(info);
      }
    }
  }

  /// Disposes this scope and its owned dependencies after all tracked work drains.
  @override
  Future<void> dispose() {
    assertCanDispose();
    final existing = _disposeFuture;
    if (existing != null) return existing;
    final completed = Completer<void>();
    _disposeFuture = completed.future;
    try {
      completed.complete(_disposeScope());
    } catch (error, stack) {
      completed.completeError(error, stack);
    }
    return completed.future;
  }

  /// Stops admission throughout this owned scope tree and requests cancellation.
  /// Await [dispose] for cleanup completion.
  void requestCancel() {
    if (_isClosing || _isDisposed) return;
    _isClosing = true;
    _notifyScopeProgress();
    if (_ownedChildren.isNotEmpty) {
      for (final child in _ownedChildren.toList()) {
        child.requestCancel();
      }
    }
    for (final info in _registry.values.toList()) {
      // Snapshot factory ownership before callbacks can mutate it. Singleton
      // registrations need no temporary resource list.
      final factories = info._factoryStorage?.toList();
      _requestResourceCancel(info.instance);
      if (factories == null) continue;
      for (final resource in factories) {
        _requestResourceCancel(resource);
      }
    }
  }

  void _requestResourceCancel(Object? resource) {
    if (resource is! LevitDrainable) return;
    try {
      resource.requestCancel();
    } catch (error, stackTrace) {
      (_cancellationFailures ??= []).add(
        LevitDisposalFailure(
          resource: resource,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  FutureOr<void> _disposeScope() {
    if (_isDisposed) return null;
    requestCancel();
    final failures = <LevitDisposalFailure>[...?_cancellationFailures];

    void finish([Object? error, StackTrace? stack]) {
      if (error != null) {
        failures.add(
          LevitDisposalFailure(
            resource: this,
            error: error,
            stackTrace: stack!,
          ),
        );
      }
      _isDisposed = true;
      _parentScope?._ownedChildrenStorage?.remove(this);
      _disposedCompleter?.complete();
      _notifyScopeProgress();
      try {
        _notifyScopeDispose();
      } catch (error, stack) {
        failures.add(
          LevitDisposalFailure(resource: this, error: error, stackTrace: stack),
        );
      }
      if (failures.isNotEmpty) {
        throw LevitDisposalException.aggregate(failures);
      }
    }

    FutureOr<void> releaseRegistrations() {
      FutureOr<void> cleanup;
      try {
        cleanup = _resetWhileClosing(failures);
      } catch (error, stack) {
        finish(error, stack);
        return null;
      }
      if (cleanup is Future<void>) {
        return cleanup.then<void>(
          (_) => finish(),
          onError: (Object error, StackTrace stack) => finish(error, stack),
        );
      }
      finish();
    }

    // A synchronous leaf scope needs only the published disposal future. Keep
    // asynchronous continuations exclusively where owned work actually awaits.
    if (_ownedChildren.isEmpty) return releaseRegistrations();
    return () async {
      for (final child in _ownedChildren.toList().reversed) {
        try {
          await child.dispose();
        } on LevitDisposalException catch (error) {
          failures.addAll(error.failures);
        } catch (error, stackTrace) {
          failures.add(
            LevitDisposalFailure(
              resource: child,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }
      await releaseRegistrations();
    }();
  }

  /// Creates a new child scope.
  ///
  /// The child scope can register its own dependencies or shadow dependencies
  /// from this parent scope.
  ///
  /// [name] is used for debugging.
  /// Children are owned by default and close before this scope's dependencies.
  /// Set [ownedByParent] to `false` for an explicitly borrowed lookup relationship.
  LevitScope createScope(String name, {bool ownedByParent = true}) {
    _ensureUsable();
    assert(() {
      LevitScope? current = this;
      while (current != null) {
        if (current.name == name) {
          _emitScopeDebugWarning(
            'LevitScope: Child scope "$name" has the same name as ancestor '
            'scope "${current.name}" (id: ${current.id}). '
            'Consider unique names for debugging clarity.',
          );
          break;
        }
        current = current._parentScope;
      }
      return true;
    }());
    final child = LevitScope._(name, parentScope: this);
    if (ownedByParent) {
      (_ownedChildrenStorage ??= LinkedHashSet<LevitScope>.identity()).add(
        child,
      );
    }
    return child;
  }

  FutureOr<void> _resetWhileClosing(List<LevitDisposalFailure> failures) {
    final entries = _registry.entries.toList(growable: false);

    for (final entry in entries) {
      final notificationFailures = _notifyDelete(
        entry.key.debugString,
        entry.value,
        'dispose',
      );
      if (notificationFailures != null) failures.addAll(notificationFailures);
      _removeCanonicalBinding(entry.key);
    }

    _aliasStorage?.clear();
    _aliasesByCanonical?.clear();
    _pendingInit?.clear();
    _typeRegistry.clear();
    _instanceCache.clear();

    // Removing each canonical binding above moves it into _retiringStorage.
    // That ordered registry already contains earlier releases and every entry here.
    final registrations =
        _retiringStorage?.values.toList(growable: false) ??
        const <LevitDependency>[];
    // No cancellation/drain phase is needed when there is no owned work. Check
    // after middleware callbacks: they may have adopted initialization cleanup.
    if (_pendingInitializations.isEmpty &&
        registrations.every(
          (info) =>
              info._pendingFactories.isEmpty &&
              info._factoryInstances.isEmpty &&
              info._initializationFailures.isEmpty &&
              info._releasedFactoryFailures.isEmpty &&
              info._cleanupFuture == null &&
              info.instance is! LevitDrainable,
        )) {
      return _disposeSimpleRegistrations(registrations);
    }
    return _disposeRegistrations(registrations.reversed);
  }

  // Avoid future/completer chains for registrations with no tracked work. A
  // disposer may still return a future; continue strictly in order after it.
  Future<void>? _disposeSimpleRegistrations(
    List<LevitDependency> registrations,
  ) {
    final failures = <LevitDisposalFailure>[];
    Set<Object>? seen;
    var index = registrations.length - 1;
    void failed(Object resource, Object error, StackTrace stack) {
      failures.add(
        LevitDisposalFailure(
          resource: resource,
          error: error,
          stackTrace: stack,
        ),
      );
    }

    Future<void>? advance() {
      while (index >= 0) {
        final info = registrations[index--];
        final instance = info.instance;
        try {
          if (instance != null &&
              (registrations.length == 1 ||
                  (seen ??= HashSet<Object>.identity()).add(instance))) {
            final cleanup = _disposeInstance(instance);
            if (cleanup is Future<void>) {
              return info._cleanupFuture = () async {
                try {
                  await cleanup;
                } catch (error, stack) {
                  failed(instance, error, stack);
                } finally {
                  _finishRegistration(info);
                }
                final remaining = advance();
                if (remaining != null) await remaining;
              }();
            }
          }
        } catch (error, stack) {
          failed(instance!, error, stack);
        }
        _finishRegistration(info);
      }
      if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
      return null;
    }

    return advance();
  }

  void _finishRegistration(LevitDependency info) {
    info._factoryStorage?.clear();
    info._removalComplete?.complete();
    _retiringStorage?.remove(info._retiringKey);
    _notifyScopeProgress();
  }

  Future<void> _disposeRegistrations(
    Iterable<LevitDependency> registrations, {
    bool includeScopeInitialization = true,
  }) async {
    final failures = <LevitDisposalFailure>[];
    final seen = HashSet<Object>.identity();
    final selected = registrations.toList();
    final pending = <Future<void>>[
      for (final info in selected) ...info._pendingFactories.toList(),
      if (_isClosing && includeScopeInitialization)
        ..._pendingInitializations.toList(),
    ];
    if (pending.isNotEmpty) await Future.wait(pending);
    final work = <LevitDrainable>{
      for (final info in selected)
        for (final instance in [info.instance, ...info._factoryInstances])
          if (instance is LevitDrainable) instance,
    };
    for (final resource in work) {
      try {
        resource.requestCancel();
      } catch (error, stackTrace) {
        failures.add(
          LevitDisposalFailure(
            resource: resource,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    for (final resource in work) {
      try {
        await resource.drain();
      } catch (error, stackTrace) {
        failures.add(
          LevitDisposalFailure(
            resource: resource,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    for (final info in selected) {
      try {
        await (info._cleanupFuture ??= _disposeRegistration(info, seen));
      } on LevitDisposalException catch (error) {
        failures.addAll(error.failures);
      }
    }
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }

  Future<void> _disposeRegistration(
    LevitDependency info,
    Set<Object> seen,
  ) async {
    final failures = <LevitDisposalFailure>[];
    try {
      // Initialization may adopt further cleanup while previously tracked work
      // drains. Collect failures only after that work has actually settled.
      while (info._pendingFactories.isNotEmpty) {
        await Future.wait(info._pendingFactories.toList());
      }
      failures.addAll(info._initializationFailures);
      failures.addAll(info._releasedFactoryFailures);
      for (final instance in [
        ...info._factoryInstances.toList().reversed,
        if (info.isInstantiated) info.instance,
      ]) {
        if (instance == null || !seen.add(instance)) continue;
        try {
          final cleanup = _disposeInstance(instance);
          if (cleanup is Future<void>) await cleanup;
        } catch (error, stackTrace) {
          failures.add(
            LevitDisposalFailure(
              resource: instance,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }
    } finally {
      _finishRegistration(info);
    }
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }

  FutureOr<void> _disposeInstance(Object instance) {
    if (instance is LevitScopeDisposable) {
      return instance.onClose();
    }
    if (instance is LevitDisposable) {
      return instance.dispose();
    }
  }

  void _removeCanonicalBinding(_LevitScopeKey key) {
    final removed = _registry.remove(key);
    if (removed != null) {
      removed._removed = true;
      removed._retiringKey = key;
      (_retiringStorage ??= {})[key] = removed;
    }
    _pendingInit?.remove(key);
    _invalidateLookupCaches(key);

    final aliases = _aliasesByCanonical?.remove(key);
    if (aliases != null) {
      for (final alias in aliases.toList(growable: false)) {
        _aliasStorage?.remove(alias);
        _invalidateLookupCaches(alias);
      }
    }
  }

  void _removeAlias(_LevitScopeKey aliasKey) {
    final canonicalKey = _aliasStorage?.remove(aliasKey);
    if (canonicalKey == null) return;

    final reverse = _aliasesByCanonical?[canonicalKey];
    reverse?.remove(aliasKey);
    if (reverse != null && reverse.isEmpty) {
      _aliasesByCanonical?.remove(canonicalKey);
    }
    _invalidateLookupCaches(aliasKey);
  }

  void _invalidateLookupCaches(_LevitScopeKey key) {
    if (key.tag == null) {
      _typeRegistry.remove(key.type);
      _instanceCache.remove(key.type);
    }
  }

  void _ensureUsable() {
    if (_isClosing || _isDisposed) {
      throw StateError('LevitScope($name) is closing or disposed.');
    }
  }

  _LevitScopeKey _getKey<S>(Object? tag) => _LevitScopeKey.of<S>(tag: tag);

  /// The number of dependencies registered locally in this scope.
  int get registeredCount => _registry.length + _aliases.length;

  /// A list of keys for all locally registered dependencies (for debugging).
  List<String> get registeredKeys => <_LevitScopeKey>[
    ..._registry.keys,
    ..._aliases.keys,
  ].map((k) => k.debugString).toList();

  @override
  String toString() {
    return 'LevitScope($name, $registeredCount local registrations)';
  }

  // Global scope middleware registry.
  static final List<LevitScopeMiddleware> _middlewares = [];
  static final Map<Object, LevitScopeMiddleware> _middlewaresByToken = {};
  static List<LevitScopeProgressObserver> _progressObservers = const [];
  static void _refreshProgressObservers() {
    _progressObservers = _middlewares
        .whereType<LevitScopeProgressObserver>()
        .toList(growable: false);
  }

  /// Adds a global middleware to be notified of DI events.
  ///
  /// Registration is idempotent by instance identity.
  /// If [token] is provided, registration is unique per token:
  /// adding another middleware with the same token replaces the previous one.
  static void addMiddleware(LevitScopeMiddleware middleware, {Object? token}) {
    if (token != null) return _addMiddlewareWithToken(token, middleware);
    if (_middlewares.contains(middleware)) return;
    _middlewares.add(middleware);
    _refreshProgressObservers();
  }

  static void _addMiddlewareWithToken(
    Object token,
    LevitScopeMiddleware middleware,
  ) {
    final existingByToken = _middlewaresByToken[token];
    if (existingByToken != null && !identical(existingByToken, middleware)) {
      return _replaceMiddlewareToken(existingByToken, token, middleware);
    }
    if (existingByToken == null) _attachMiddlewareToken(token, middleware);
  }

  static void _attachMiddlewareToken(
    Object token,
    LevitScopeMiddleware middleware,
  ) {
    if (_middlewares.contains(middleware)) {
      _middlewaresByToken[token] = middleware;
      return;
    }
    _middlewares.add(middleware);
    _middlewaresByToken[token] = middleware;
    _refreshProgressObservers();
  }

  static void _replaceMiddlewareToken(
    LevitScopeMiddleware existingByToken,
    Object token,
    LevitScopeMiddleware middleware,
  ) {
    _replaceOrAppendMiddleware(existingByToken, middleware);
    _middlewaresByToken[token] = middleware;
  }

  static void _replaceOrAppendMiddleware(
    LevitScopeMiddleware existing,
    LevitScopeMiddleware replacement,
  ) {
    final index = _middlewares.indexOf(existing);
    if (index >= 0) {
      _middlewares[index] = replacement;
    } else {
      _middlewares.add(replacement);
    }
    _refreshProgressObservers();
  }

  /// Removes a previously added middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    if (_middlewares.remove(middleware)) {
      _middlewaresByToken.removeWhere(
        (_, registered) => identical(registered, middleware),
      );
      _refreshProgressObservers();
    }
  }

  /// Removes a middleware by [token].
  static bool removeMiddlewareByToken(Object token) {
    final middleware = _middlewaresByToken.remove(token);
    if (middleware == null || !_middlewares.remove(middleware)) return false;
    _refreshProgressObservers();
    return true;
  }

  /// Returns `true` if [middleware] is currently registered.
  static bool containsMiddleware(LevitScopeMiddleware middleware) =>
      _middlewares.contains(middleware);

  /// Returns `true` if a middleware is currently registered under [token].
  static bool containsMiddlewareToken(Object token) =>
      _middlewaresByToken.containsKey(token);

  /// Returns `true` if at least one [LevitScopeMiddleware] is registered.
  static bool get hasMiddlewares => _middlewares.isNotEmpty;

  void _notifyRegister(String key, LevitDependency info, String source) {
    info._scope = this;
    _notifyScopeProgress();
    _LevitScopeMiddlewareChain.applyOnRegister(
      id,
      name,
      key,
      info,
      source,
      _parentScope?.id,
    );
  }

  void _notifyResolve(String key, LevitDependency info, String source) {
    _LevitScopeMiddlewareChain.applyOnResolve(
      id,
      name,
      key,
      info,
      source,
      _parentScope?.id,
    );
  }

  S Function() _applyCreateInstanceHooks<S>(
    S Function() builder,
    String key,
    LevitDependency info,
  ) {
    return _LevitScopeMiddlewareChain.applyOnCreate<S>(
      builder,
      this,
      key,
      info,
    );
  }

  List<LevitDisposalFailure>? _notifyDelete(
    String key,
    LevitDependency info,
    String source,
  ) {
    _notifyScopeProgress();
    return _LevitScopeMiddlewareChain.applyOnDelete(
      id,
      name,
      key,
      info,
      source,
      _parentScope?.id,
    );
  }

  void _applyInitHooks<S>(
    S instance,
    void Function() onInit,
    String key,
    LevitDependency info,
  ) {
    final wrapped = _LevitScopeMiddlewareChain.applyOnDependencyInit<S>(
      onInit,
      instance,
      this,
      key,
      info,
    );
    _guardInitialization<FutureOr<void>>(() {
      wrapped();
      if (info._pendingFactories.isNotEmpty) {
        return Future.wait(info._pendingFactories.toList()).then<void>((_) {});
      }
    }, registration: info);
    _notifyScopeProgress();
  }

  void _notifyScopeProgress() {
    if (_progressObservers.isEmpty) return;
    for (final observer in _progressObservers) {
      try {
        observer.onScopeProgress(describe());
      } catch (error, stack) {
        dev.log(
          'Scope progress observer failed',
          error: error,
          stackTrace: stack,
          name: 'levit_scope',
        );
      }
    }
  }

  void _notifyScopeCreate() {
    _LevitScopeMiddlewareChain.applyOnScopeCreate(id, name, _parentScope?.id);
  }

  void _notifyScopeDispose() {
    _LevitScopeMiddlewareChain.applyOnScopeDispose(id, name);
  }
}

final class _ScopeInitialization {
  _ScopeInitialization(this.scope, this.registration, this.parent);
  final LevitScope scope;
  final LevitDependency? registration;
  final _ScopeInitialization? parent;
  bool active = true;
}

void _emitScopeDebugWarning(String message) {
  dev.log(message, name: 'levit_scope');
  Zone.current.print(message);
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
      wrapped = observer.onDependencyInit<S>(
        wrapped,
        instance,
        scope,
        key,
        info,
      );
    }
    return wrapped;
  }

  static void applyOnRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info,
    String source,
    int? parentScopeId,
  ) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDependencyRegister(
        scopeId,
        scopeName,
        key,
        info,
        source: source,
        parentScopeId: parentScopeId,
      );
    }
  }

  static void applyOnResolve(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info,
    String source,
    int? parentScopeId,
  ) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onDependencyResolve(
        scopeId,
        scopeName,
        key,
        info,
        source: source,
        parentScopeId: parentScopeId,
      );
    }
  }

  static List<LevitDisposalFailure>? applyOnDelete(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info,
    String source,
    int? parentScopeId,
  ) {
    if (LevitScope._middlewares.isEmpty) return null;
    List<LevitDisposalFailure>? failures;
    for (final observer in LevitScope._middlewares) {
      try {
        observer.onDependencyDelete(
          scopeId,
          scopeName,
          key,
          info,
          source: source,
          parentScopeId: parentScopeId,
        );
      } catch (error, stack) {
        (failures ??= []).add(
          LevitDisposalFailure(
            resource: observer,
            error: error,
            stackTrace: stack,
          ),
        );
      }
    }
    return failures;
  }

  static void applyOnScopeCreate(
    int scopeId,
    String scopeName,
    int? parentScopeId,
  ) {
    if (LevitScope._middlewares.isEmpty) return;
    for (final observer in LevitScope._middlewares) {
      observer.onScopeCreate(scopeId, scopeName, parentScopeId);
    }
  }

  static void applyOnScopeDispose(int scopeId, String scopeName) {
    if (LevitScope._middlewares.isEmpty) return;
    List<LevitDisposalFailure>? failures;
    for (final observer in LevitScope._middlewares) {
      try {
        observer.onScopeDispose(scopeId, scopeName);
      } catch (error, stack) {
        (failures ??= []).add(
          LevitDisposalFailure(
            resource: observer,
            error: error,
            stackTrace: stack,
          ),
        );
      }
    }
    if (failures != null) throw LevitDisposalException.aggregate(failures);
  }
}
