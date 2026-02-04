part of '../levit_scope.dart';

/// The global entry point for accessing the [LevitScope] system.
///
/// [Ls] ("Levit Scope") acts as a static proxy to the currently active [LevitScope].
/// It uses [Zone] values to determine the current scope context, defaulting to the
/// root scope if none is active.
///
/// Example:
/// ```dart
/// // Finds 'AuthService' in the current scope
/// final auth = Ls.find<AuthService>();
/// ```
class Ls {
  static final _root = LevitScope.root();

  /// The [Zone] key used to identifying the active [LevitScope].
  static final Object zoneScopeKey = Object();

  /// Returns the currently active [LevitScope].
  ///
  /// If run within a [LevitScopeImplicitScopeExtension.run] zone, returns that
  /// scope.
  /// Otherwise, returns the global root scope.
  static LevitScope get currentScope {
    final implicit = Zone.current[Ls.zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Instantiates and registers a dependency in the active scope.
  ///
  /// The [builder] is executed immediately.
  ///
  /// Example:
  /// ```dart
  /// Ls.put(() => MyService());
  /// ```
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to persist the instance across resets.
  ///
  /// Returns the created instance.
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return currentScope.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency in the active scope.
  ///
  /// The [builder] is executed only when the dependency is first requested.
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to persist the registration across resets.
  /// Set [isFactory] to `true` to create a new instance every time [find] is called.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    currentScope.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous dependency in the active scope.
  ///
  /// Use [Ls.findAsync] to retrieve the instance.
  ///
  /// Use [tag] to differentiate multiple instances of the same type.
  /// Set [permanent] to `true` to persist the registration across resets.
  /// Set [isFactory] to `true` to re-run the builder for every [findAsync] call.
  static Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return currentScope.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Finds a registered instance of type [S] in the active scope.
  ///
  /// Throws an [Exception] if the dependency is not found.
  static S find<S>({String? tag}) {
    return currentScope.find<S>(tag: tag);
  }

  /// Finds a registered instance of type [S] in the active scope, or `null`.
  static S? findOrNull<S>({String? tag}) {
    return currentScope.findOrNull<S>(tag: tag);
  }

  /// Asynchronously finds a registered instance of type [S] in the active scope.
  ///
  /// Throws an [Exception] if the dependency is not found.
  static Future<S> findAsync<S>({String? tag}) {
    return currentScope.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds a registered instance of type [S], or returns `null`.
  static Future<S?> findOrNullAsync<S>({String? tag}) {
    return currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the active or any parent scope.
  static bool isRegistered<S>({String? tag}) {
    return currentScope.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] has been instantiated in the active or parent scope.
  static bool isInstantiated<S>({String? tag}) {
    return currentScope.isInstantiated<S>(tag: tag);
  }

  /// Removes a dependency from the active scope.
  ///
  /// If [force] is `true`, permanent dependencies are also removed.
  /// Returns `true` if the dependency was found and removed.
  static bool delete<S>({String? tag, bool force = false}) {
    return currentScope.delete<S>(tag: tag, force: force);
  }

  /// Disposes all non-permanent dependencies in the active scope.
  ///
  /// Set [force] to `true` to also dispose permanent dependencies.
  static void reset({bool force = false}) {
    currentScope.reset(force: force);
  }

  /// Creates a child scope from the active scope.
  ///
  /// [name] is used for debugging.
  static LevitScope createScope(String name) {
    return currentScope.createScope(name);
  }

  /// The number of dependencies registered in the active scope.
  static int get registeredCount => currentScope.registeredCount;

  /// A list of keys for all dependencies in the active scope.
  static List<String> get registeredKeys => currentScope.registeredKeys;

  /// Adds a global middleware to intercept dependency injection events.
  static void addMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.addMiddleware(middleware);
  }

  /// Removes a global middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.removeMiddleware(middleware);
  }
}

/// Extensions for executing code within a specific [LevitScope].
extension LevitScopeImplicitScopeExtension on LevitScope {
  /// Executes [callback] with this scope as the active [Ls.currentScope].
  ///
  /// Returns the result of [callback].
  R run<R>(R Function() callback) {
    return runZoned(
      callback,
      zoneValues: {Ls.zoneScopeKey: this},
    );
  }
}
