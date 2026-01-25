part of '../levit_dart_core.dart';

/// The primary entry point in Levit.
class Levit {
  // ------------------------------------------------------------
  //    Reactive API accessors
  // ------------------------------------------------------------

  /// Whether to capture stack traces on state changes (performance intensive).
  static bool get captureStackTrace => Lx.captureStackTrace;

  static set captureStackTrace(bool value) {
    Lx.captureStackTrace = value;
  }

  /// Global flag to enable or disable performance monitoring for all [LxWorker] instances.
  static bool get enableWatchMonitoring => Lx.enableWatchMonitoring;

  static set enableWatchMonitoring(bool value) {
    Lx.enableWatchMonitoring = value;
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications for all variables mutated inside the batch are deferred
  /// until the callback completes, ensuring only a single notification per variable.
  static R batch<R>(R Function() callback) {
    return Lx.batch(callback);
  }

  /// Executes asynchronous [callback] in a batch.
  ///
  /// Like [batch], but maintains the batching context across asynchronous gaps.
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return Lx.batchAsync(callback);
  }

  /// Executes [action] while temporarily bypassing all registered middlewares.
  static void runWithoutStateMiddleware(void Function() action) {
    Lx.runWithoutMiddleware(action);
  }

  /// Removes all active state middlewares.
  static void clearStateMiddlewares() {
    Lx.clearMiddlewares();
  }

  /// Checks if a particular state middleware is currently registered.
  static bool containsStateMiddleware(LevitReactiveMiddleware middleware) {
    return Lx.containsMiddleware(middleware);
  }

  /// The context is passed to [LevitReactiveMiddleware.startedListening]
  /// and [LevitReactiveMiddleware.stoppedListening].
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return Lx.runWithContext(context, fn);
  }

  // ------------------------------------------------------------
  //    Levit API accessors
  // ------------------------------------------------------------

  /// Instantiates and registers a dependency using a [builder].
  ///
  /// The [builder] is executed immediately. If [Levit.enableAutoLinking] is
  /// active, any reactive variables created during execution are automatically
  /// captured and linked to the resulting instance for cleanup.
  ///
  /// // Example usage:
  /// ```dart
  /// final service = Levit.put(() => MyService());
  /// ```
  ///
  /// Parameters:
  /// - [builder]: A function that creates the dependency instance.
  /// - [tag]: Optional unique identifier to allow multiple instances of the same type [S].
  /// - [permanent]: If `true`, this instance survives a non-forced [reset].
  ///
  /// Returns the created instance of type [S].
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return Ls.put<S>(builder, tag: tag, permanent: permanent);
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
    Ls.lazyPut<S>(builder,
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
    return Ls.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// * [key]: A specific key or [LevitState] to resolve.
  /// * [tag]: The unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found for [S], [key] or [tag].
  static S find<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
      return key.findIn(Ls.currentScope, tag: tag) as S;
    }
    return Ls.find<S>(tag: tag);
  }

  /// Retrieves the registered instance of type [S], or returns `null` if not found.
  ///
  /// * [key]: A specific key or [LevitState] to resolve.
  /// * [tag]: The unique identifier used during registration.
  static S? findOrNull<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
      try {
        return key.findIn(Ls.currentScope, tag: tag) as S;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNull<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S].
  ///
  /// Useful for dependencies registered via [lazyPutAsync].
  ///
  /// * [key]: A specific key or [LevitState] to resolve.
  /// * [tag]: The unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found.
  static Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitState) {
      final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S], or returns `null`.
  ///
  /// * [key]: A specific key or [LevitState] to resolve.
  /// * [tag]: The unique identifier used during registration.
  static Future<S?> findOrNullAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitState) {
      try {
        final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
        if (result is Future) return await result as S?;
        return result as S?;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the current or any parent scope.
  static bool isRegistered<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
      return key.isRegisteredIn(Ls.currentScope, tag: tag);
    }
    return Ls.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] has already been instantiated.
  static bool isInstantiated<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
      return key.isInstantiatedIn(Ls.currentScope, tag: tag);
    }
    return Ls.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  ///
  /// Parameters:
  /// - [key]: A specific key or [LevitState] to delete.
  /// - [tag]: The unique identifier used during registration.
  /// - [force]: If `true`, deletes even if the dependency was marked as `permanent`.
  ///
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({dynamic key, String? tag, bool force = false}) {
    if (key is LevitState) {
      return key.deleteIn(Ls.currentScope, tag: tag, force: force);
    }
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// * [force]: If `true`, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    Ls.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// child scopes can override parent dependencies and provide their own
  /// isolated lifecycle.
  ///
  /// * [name]: A descriptive name for the scope (used in profiling and logs).
  static LevitScope createScope(String name) {
    return Ls.createScope(name);
  }

  // -------------------------------------------------------------
  //    Middleware accessors
  // -------------------------------------------------------------

  /// The total number of dependencies registered in the current active scope.
  static int get registeredCount => Ls.registeredCount;

  /// A list of all registration keys (type + tag) in the current active scope.
  static List<String> get registeredKeys => Ls.registeredKeys;

  /// Adds a global middleware for receiving dependency injection events.
  static void addDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.addMiddleware(middleware);
  }

  /// Removes a DI middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    Ls.removeMiddleware(middleware);
  }

  /// Adds a middleware to the list of active middlewares.
  static void addStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.addMiddleware(middleware);
  }

  /// Removes a middleware from the list of active middlewares.
  static void removeStateMiddleware(LevitReactiveMiddleware middleware) {
    Lx.removeMiddleware(middleware);
  }

  // -------------------------------------------------------------
  //   Auto-Linking
  // -------------------------------------------------------------

  /// Enables the "Auto-Linking" feature.
  ///
  /// When enabled, any [LxReactive] variable created inside a [Levit.put] builder or
  /// [LevitController.onInit] is automatically registered for cleanup with
  /// its parent controller.
  ///
  /// This ensures that transient state created within business logic components
  /// is deterministically cleaned up without manual tracking.
  static void enableAutoLinking() {
    Lx.addMiddleware(_AutoLinkMiddleware());
    LevitScope.addMiddleware(_AutoDisposeMiddleware());
  }

  /// Disables the "Auto-Linking" feature.
  static void disableAutoLinking() {
    Lx.removeMiddleware(_AutoLinkMiddleware());
    LevitScope.removeMiddleware(_AutoDisposeMiddleware());
  }
}

/// Fluent API for naming reactive variables.
extension LxNamingExtension<R extends LxReactive> on R {
  /// Sets the debug name of this reactive object and returns it.
  ///
  /// Useful for chaining:
  /// ```dart
  /// final count = 0.lx.named('count');
  /// ```
  R named(String name) {
    this.name = name;
    return this;
  }

  /// Registers this reactive object with an owner (fluent API).
  R register(String ownerId) {
    this.ownerId = ownerId;

    return this;
  }
}
