part of 'scope_library.dart';

/// Low-level runtime hooks exposed via `package:levit_scope/spi.dart`.
///
/// {@category SPI}
abstract final class LsSpi {
  static final Object _zoneScopeKey = Object();
  static bool _zoneKeyExposed = false;

  /// The [Zone] key used to identify the active [LevitScope].
  static Object get zoneScopeKey {
    _zoneKeyExposed = true;
    return _zoneScopeKey;
  }

  /// Synchronously sets [scope] as [Ls.currentScope] and returns the previous
  /// synchronous override for restoration via [exitSyncScope].
  ///
  /// Enables zero-closure scope bridging inside hot-path synchronous frames
  /// (such as Flutter `Element.build`). Always pair with [exitSyncScope] in a
  /// `try`/`finally` block.
  static LevitScope? enterSyncScope(LevitScope scope) {
    final previous = Ls._syncScope;
    Ls._syncScope = scope;
    return previous;
  }

  /// Restores the synchronous scope override returned by [enterSyncScope].
  static void exitSyncScope(LevitScope? previous) {
    Ls._syncScope = previous;
  }

  /// Synchronously binds [scope] as [Ls.currentScope] for the duration of [fn]
  /// without allocating a new [Zone].
  ///
  /// Nested [LevitScopeImplicitScopeExtension.run] calls override this binding
  /// and restore it when they exit. Intended for synchronous build frames
  /// (such as Flutter `Widget.build`).
  static R runSyncWithScope<R>(LevitScope scope, R Function() fn) {
    final previous = enterSyncScope(scope);
    try {
      return fn();
    } finally {
      exitSyncScope(previous);
    }
  }
}

/// The low-level global entry point for accessing the [LevitScope] system.
///
/// [Ls] ("Levit Scope") acts as a static proxy to the currently active [LevitScope].
/// It uses [Zone] values to determine the current scope context, defaulting to the
/// root scope if none is active.
///
/// High-level kits (`levit`, `levit_dart`, and `levit_flutter`) intentionally
/// hide [Ls] in favor of the unified `Levit` facade (`Levit.currentScope`,
/// `Levit.put`, `Levit.find`, etc.).
///
/// ```dart
/// // Finds AuthService in the current scope
/// final auth = Ls.find<AuthService>();
/// ```
///
/// {@category Scopes & DI}
class Ls {
  static final _root = LevitScope.root();
  static LevitScope? _syncScope;
  static int _activeZoneScopeDepth = 0;

  /// Returns the currently active [LevitScope].
  ///
  /// If run within a [LevitScopeImplicitScopeExtension.run] zone or a
  /// synchronous scope bridge, returns that scope.
  /// Otherwise, returns the global root scope.
  static LevitScope get currentScope {
    final sync = _syncScope;
    if (sync != null) return sync;
    if (_activeZoneScopeDepth == 0 && !LsSpi._zoneKeyExposed) {
      return _root;
    }
    final implicit = Zone.current[LsSpi._zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Instantiates and registers a dependency in the active scope.
  ///
  /// The [builder] is executed immediately.
  ///
  /// ```dart
  /// Ls.put(() => MyService());
  /// ```
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to survive a *non-forced* reset only.
  /// Scope [LevitScope.dispose] always force-clears permanents.
  /// Prefer permanent on root / long-lived scopes.
  ///
  /// Returns the created instance.
  static S put<S>(S Function() builder, {Object? tag, bool permanent = false}) {
    return currentScope.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency in the active scope.
  ///
  /// The [builder] is executed only when the dependency is first requested.
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to survive a *non-forced* reset only.
  /// Scope [LevitScope.dispose] always force-clears permanents.
  /// Set [isFactory] to `true` to create a new instance every time [find] is called.
  static void lazyPut<S>(
    S Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    currentScope.lazyPut<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  /// Registers an asynchronous dependency in the active scope.
  ///
  /// Use [Ls.findAsync] to retrieve the instance.
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to survive a *non-forced* reset only.
  /// Scope [LevitScope.dispose] always force-clears permanents.
  /// Set [isFactory] to `true` to re-run the builder for every [findAsync] call.
  static Future<S> Function() lazyPutAsync<S>(
    Future<S> Function() builder, {
    Object? tag,
    bool permanent = false,
    bool isFactory = false,
  }) {
    return currentScope.lazyPutAsync<S>(
      builder,
      tag: tag,
      permanent: permanent,
      isFactory: isFactory,
    );
  }

  /// Binds [Alias] to an existing local singleton [Concrete].
  static void bindExisting<Alias, Concrete extends Alias>({
    Object? sourceTag,
    Object? tag,
  }) {
    currentScope.bindExisting<Alias, Concrete>(sourceTag: sourceTag, tag: tag);
  }

  /// Finds a registered instance of type [S] in the active scope.
  ///
  /// Throws an [Exception] if the dependency is not found.
  static S find<S>({Object? tag}) {
    return currentScope.find<S>(tag: tag);
  }

  /// Finds a registered instance of type [S] in the active scope, or `null`.
  static S? findOrNull<S>({Object? tag}) {
    return currentScope.findOrNull<S>(tag: tag);
  }

  /// Asynchronously finds a registered instance of type [S] in the active scope.
  ///
  /// Throws an [Exception] if the dependency is not found.
  static Future<S> findAsync<S>({Object? tag}) {
    return currentScope.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds a registered instance of type [S], or returns `null`.
  static Future<S?> findOrNullAsync<S>({Object? tag}) {
    return currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the active or any parent scope.
  static bool isRegistered<S>({Object? tag}) {
    return currentScope.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] has been instantiated in the active or parent scope.
  static bool isInstantiated<S>({Object? tag}) {
    return currentScope.isInstantiated<S>(tag: tag);
  }

  /// Removes a dependency from the active scope.
  ///
  /// If [force] is `true`, permanent dependencies are also removed.
  /// Returns `true` if the dependency was found and removed.
  static Future<bool> delete<S>({Object? tag, bool force = false}) {
    return currentScope.delete<S>(tag: tag, force: force);
  }

  /// Disposes all non-permanent dependencies in the active scope.
  ///
  /// Set [force] to `true` to also dispose permanent dependencies.
  static Future<void> reset({bool force = false}) {
    return currentScope.reset(force: force);
  }

  /// Creates a child scope from the active scope.
  ///
  /// [name] is used for debugging.
  static LevitScope createScope(String name, {bool ownedByParent = true}) {
    return currentScope.createScope(name, ownedByParent: ownedByParent);
  }

  /// The number of dependencies registered in the active scope.
  static int get registeredCount => currentScope.registeredCount;

  /// A list of keys for all dependencies in the active scope.
  static List<String> get registeredKeys => currentScope.registeredKeys;

  /// Adds a global middleware to intercept dependency injection events.
  static void addMiddleware(LevitScopeMiddleware middleware, {Object? token}) {
    LevitScope.addMiddleware(middleware, token: token);
  }

  /// Removes a global middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.removeMiddleware(middleware);
  }

  /// Removes a global middleware by [token].
  static bool removeMiddlewareByToken(Object token) {
    return LevitScope.removeMiddlewareByToken(token);
  }
}

R _scopeRunHandler<R>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function() f,
) {
  final previousSync = Ls._syncScope;
  Ls._syncScope = null;
  Ls._activeZoneScopeDepth++;
  try {
    return parent.run(zone, f);
  } finally {
    Ls._activeZoneScopeDepth--;
    Ls._syncScope = previousSync;
  }
}

R _scopeRunUnaryHandler<R, T>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function(T) f,
  T arg,
) {
  final previousSync = Ls._syncScope;
  Ls._syncScope = null;
  Ls._activeZoneScopeDepth++;
  try {
    return parent.runUnary(zone, f, arg);
  } finally {
    Ls._activeZoneScopeDepth--;
    Ls._syncScope = previousSync;
  }
}

R _scopeRunBinaryHandler<R, T1, T2>(
  Zone self,
  ZoneDelegate parent,
  Zone zone,
  R Function(T1, T2) f,
  T1 arg1,
  T2 arg2,
) {
  final previousSync = Ls._syncScope;
  Ls._syncScope = null;
  Ls._activeZoneScopeDepth++;
  try {
    return parent.runBinary(zone, f, arg1, arg2);
  } finally {
    Ls._activeZoneScopeDepth--;
    Ls._syncScope = previousSync;
  }
}

final ZoneSpecification _staticScopeZoneSpec = ZoneSpecification(
  run: _scopeRunHandler,
  runUnary: _scopeRunUnaryHandler,
  runBinary: _scopeRunBinaryHandler,
);

/// Extensions for executing code within a specific [LevitScope].
///
/// {@category Scopes & DI}
extension LevitScopeImplicitScopeExtension on LevitScope {
  /// Executes [callback] with this scope bound as the active scope in the
  /// current [Zone].
  ///
  /// Unlike `Levit.runInScope`, this does not dispose the scope when [callback]
  /// completes; the caller remains responsible for awaiting [LevitScope.dispose].
  ///
  /// Returns the result of [callback].
  R run<R>(R Function() callback) {
    return runZoned(
      callback,
      zoneValues: {LsSpi._zoneScopeKey: this},
      zoneSpecification: _staticScopeZoneSpec,
    );
  }
}
