part of '../levit_scope.dart';

/// The primary entry point for managing dependencies and ambient scopes.
///
/// [Ls] provides a unified, static interface for interacting with the
/// dependency injection system. It leverages [Zone]-based implicit propagation
/// to simplify access to the current [LevitScope].
///
/// // Example usage:
/// ```dart
/// // Implicitly targets the active scope
/// final auth = Ls.find<AuthService>();
/// ```
class Ls {
  static final _root = LevitScope.root();

  /// The internal [Zone] key used to find the active scope.
  static final Object zoneScopeKey = Object();

  /// Retrieves the current active [LevitScope].
  ///
  /// Returns the scope associated with the current [Zone], or the root scope
  /// if no explicit scope is active.
  static LevitScope get currentScope {
    final implicit = Zone.current[Ls.zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Instantiates and registers a dependency using a [builder].
  ///
  /// The [builder] is executed immediately.
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Ls.put(() => MyService());
  /// ```
  ///
  /// Parameters:
  /// - [builder]: A function that creates the dependency instance.
  /// - [tag]: Optional unique identifier to allow multiple instances of the same type [S].
  /// - [permanent]: If `true`, this instance survives a non-forced [reset].
  ///
  /// Returns the created instance of type [S].
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return currentScope.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  ///
  /// Parameters:
  /// - [builder]: A function that creates the dependency instance.
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the registration persists through a [reset].
  /// - [isFactory]: If `true`, a new instance is created every time [find] is called.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    currentScope.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous [builder] for lazy instantiation.
  ///
  /// Use [findAsync] to retrieve the instance once the future completes.
  ///
  /// * [builder]: A function returning a [Future] of the dependency.
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration persists through a [reset].
  /// * [isFactory]: If `true`, the builder is re-run for every [findAsync] call.
  static Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return currentScope.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Retrieves the registered instance of type [S].
  ///
  /// If the instance is not found in the current scope, it searches upward through
  /// parent scopes.
  ///
  /// * [tag]: The unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found for [S] and [tag].
  static S find<S>({String? tag}) {
    return currentScope.find<S>(tag: tag);
  }

  /// Retrieves the registered instance of type [S], or returns `null` if not found.
  ///
  /// * [tag]: The unique identifier used during registration.
  static S? findOrNull<S>({String? tag}) {
    return currentScope.findOrNull<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S].
  ///
  /// Useful for dependencies registered via [lazyPutAsync].
  ///
  /// * [tag]: The unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found.
  static Future<S> findAsync<S>({String? tag}) {
    return currentScope.findAsync<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S], or returns `null`.
  ///
  /// * [tag]: The unique identifier used during registration.
  static Future<S?> findOrNullAsync<S>({String? tag}) {
    return currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the current or any parent scope.
  static bool isRegistered<S>({String? tag}) {
    return currentScope.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] has already been instantiated.
  static bool isInstantiated<S>({String? tag}) {
    return currentScope.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  ///
  /// Parameters:
  /// - [tag]: The unique identifier used during registration.
  /// - [force]: If `true`, deletes even if the dependency was marked as `permanent`.
  ///
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({String? tag, bool force = false}) {
    return currentScope.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// * [force]: If `true`, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    currentScope.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// child scopes can override parent dependencies and provide their own
  /// isolated lifecycle.
  ///
  /// * [name]: A descriptive name for the scope (used in profiling and logs).
  static LevitScope createScope(String name) {
    return currentScope.createScope(name);
  }

  /// The total number of dependencies registered in the current active scope.
  static int get registeredCount => currentScope.registeredCount;

  /// A list of all registration keys (type + tag) in the current active scope.
  static List<String> get registeredKeys => currentScope.registeredKeys;

  /// Adds a global middleware for receiving dependency injection events.
  static void addMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.addMiddleware(middleware);
  }

  /// Removes a DI middleware.
  static void removeMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.removeMiddleware(middleware);
  }
}

/// Implicit scoping extensions for [LevitScope].
extension LevitScopeImplicitScopeExtension on LevitScope {
  /// Executes the [callback] within a [Zone] where this scope is active.
  ///
  /// Any calls to static methods like [Ls.find] or [Ls.put] inside the
  /// [callback] will automatically target this scope.
  ///
  /// Returns the result of the [callback].
  R run<R>(R Function() callback) {
    return runZoned(
      callback,
      zoneValues: {Ls.zoneScopeKey: this},
    );
  }
}
