part of '../levit_dart_core.dart';

/// The central entry point for the Levit framework.
///
/// [Levit] unifies the capabilities of [LevitScope] (DI) and [Lx] (Reactivity)
/// into a single, cohesive API. It manages controller lifecycles, configuration,
/// and global middleware.
class Levit {
  // ------------------------------------------------------------
  //    Reactive API accessors
  // ------------------------------------------------------------

  /// Whether to capture stack traces on state changes.
  ///
  /// Enabling this incurs a significant performance penalty.
  /// Use only for debugging.
  static bool get captureStackTrace => Lx.captureStackTrace;

  static set captureStackTrace(bool value) {
    Lx.captureStackTrace = value;
  }

  /// Whether to monitor performance metrics for [LxWorker].
  static bool get enableWatchMonitoring => Lx.enableWatchMonitoring;

  static set enableWatchMonitoring(bool value) {
    Lx.enableWatchMonitoring = value;
  }

  /// Executes [callback] in a synchronous batch.
  ///
  /// Notifications are deferred until the batch completes, ensuring that
  /// observers are only notified once even if multiple values change.
  ///
  /// Example:
  /// ```dart
  /// Levit.batch(() {
  ///   firstName.value = 'Jane';
  ///   lastName.value = 'Doe';
  /// });
  /// ```
  static R batch<R>(R Function() callback) {
    return Lx.batch(callback);
  }

  /// Executes an asynchronous [callback] in a batch.
  ///
  /// The batching context is maintained across await points.
  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return Lx.batchAsync(callback);
  }

  /// Bypasses all state middlewares for the duration of [action].
  static void runWithoutStateMiddleware(void Function() action) {
    Lx.runWithoutMiddleware(action);
  }

  /// Clears all registered state middlewares.
  static void clearStateMiddlewares() {
    Lx.clearMiddlewares();
  }

  /// Checks if [middleware] is currently registered.
  static bool containsStateMiddleware(LevitReactiveMiddleware middleware) {
    return Lx.containsMiddleware(middleware);
  }

  /// Executes [fn] within a specific listener context.
  ///
  /// Used internally to attribute subscriptions to specific widgets or controllers.
  static T runWithContext<T>(LxListenerContext context, T Function() fn) {
    return Lx.runWithContext(context, fn);
  }

  // ------------------------------------------------------------
  //    Levit API accessors
  // ------------------------------------------------------------

  /// Instantiates and registers a dependency.
  ///
  /// The [builder] is executed immediately.
  /// If [permanent] is true, the instance survives [reset].
  ///
  /// Example:
  /// ```dart
  /// final service = Levit.put(() => AuthService());
  /// ```
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return Ls.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency builder.
  ///
  /// The [builder] runs only when the dependency is first requested.
  ///
  /// *   If [isFactory] is true, [builder] runs on every request.
  /// *   If [permanent] is true, registration survives [reset].
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    Ls.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous lazy dependency builder.
  ///
  /// Retrieve the instance using [findAsync].
  static Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    return Ls.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Finds a registered instance of type [S].
  ///
  /// Throws if not found. Use [key] to search within a specific [LevitStore].
  ///
  /// Example:
  /// ```dart
  /// final service = Levit.find<AuthService>();
  /// ```
  static S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.findIn(Ls.currentScope, tag: tag) as S;
    }
    return Ls.find<S>(tag: tag);
  }

  /// Finds an instance of type [S], or returns `null` if missing.
  static S? findOrNull<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      try {
        return key.findIn(Ls.currentScope, tag: tag) as S;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNull<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S].
  ///
  /// Use for dependencies registered via [lazyPutAsync].
  static Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
      if (result is Future && result is! S) return await result as S;
      return result as S;
    }
    return Ls.findAsync<S>(tag: tag);
  }

  /// Asynchronously finds an instance of type [S], or returning `null`.
  static Future<S?> findOrNullAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      try {
        final result = await key.findAsyncIn(Ls.currentScope, tag: tag);
        if (result is Future && result is! S?) return await result as S?;
        return result as S?;
      } catch (_) {
        return null;
      }
    }
    return Ls.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered.
  static bool isRegistered<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.isRegisteredIn(Ls.currentScope, tag: tag);
    }
    return Ls.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] is already instantiated (not just pending lazy init).
  static bool isInstantiated<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      return key.isInstantiatedIn(Ls.currentScope, tag: tag);
    }
    return Ls.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  /// If [force] is true, deletes even if the dependency was marked as `permanent`.
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({dynamic key, String? tag, bool force = false}) {
    if (key is LevitStore) {
      return key.deleteIn(Ls.currentScope, tag: tag, force: force);
    }
    return Ls.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// If [force] is true, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    Ls.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// Child scopes can override parent dependencies and provide their own
  /// isolated lifecycle. The [name] is used for profiling and logs.
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

  /// Enables automatic linking of reactive state to controller lifecycles.
  ///
  /// When enabled, [LxReactive] objects created inside [LevitController.onInit]
  /// or [LevitApp.onInit] are automatically disposed when the controller is closed.
  static void enableAutoLinking() {
    Lx.addMiddleware(_AutoLinkMiddleware());
    LevitScope.addMiddleware(_AutoDisposeMiddleware());
  }

  /// Disables automatic linking.
  static void disableAutoLinking() {
    Lx.removeMiddleware(_AutoLinkMiddleware());
    LevitScope.removeMiddleware(_AutoDisposeMiddleware());
  }

// -------------------------------------------------------------
//    Internal utils
// -------------------------------------------------------------

  /// Internal utility that detects and executes the appropriate cleanup method for an [item].
  static void _levitDisposeItem(dynamic item) {
    if (item == null) return;

    // 1. Framework Specifics (Priority)

    if (item is LxReactive) {
      item.close();
      return;
    }

    if (item is LevitScopeDisposable) {
      item.onClose();
      return;
    }

    if (item is LevitDisposable) {
      item.dispose();
      return;
    }

    // 2. The "Cancel" Group (Async tasks)
    // Most common: StreamSubscription, Timer
    if (item is StreamSubscription) {
      item.cancel();
      return;
    }
    if (item is Timer) {
      item.cancel();
      return;
    }

    try {
      // Duck typing for other cancelables (like CancelableOperation)
      (item as dynamic).cancel();
      return;
    } on NoSuchMethodError {
      // Not cancelable, fall through
    } on Exception catch (e) {
      // Prevent crash during cleanup (only for Exceptions)
      dev.log('Levit: Error cancelling ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 3. The "Dispose" Group (Flutter Controllers)
    // Most common: TextEditingController, ChangeNotifier, FocusNode
    try {
      (item as dynamic).dispose();
      return;
    } on NoSuchMethodError {
      // Not disposable, fall through
    } on Exception catch (e) {
      dev.log('Levit: Error disposing ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 4. The "Close" Group (Sinks, BLoCs, IO)
    // Most common: StreamController, Sink, Bloc
    if (item is Sink) {
      item.close();
      return;
    }

    try {
      (item as dynamic).close();
      return;
    } on NoSuchMethodError {
      // Not closeable, fall through
    } on Exception catch (e) {
      dev.log('Levit: Error closing ${item.runtimeType}',
          error: e, name: 'levit_dart');
    }

    // 5. The "Callable" Group (Cleanup Callbacks)
    if (item is void Function()) {
      try {
        item();
      } catch (e) {
        dev.log('Levit: Error executing dispose callback',
            error: e, name: 'levit_dart');
      }
      return;
    }
  }
}

/// Fluent extensions for naming and configuring reactive objects.
extension LxNamingExtension<R extends LxReactive> on R {
  /// assigns a debug [name] to this reactive object.
  R named(String name) {
    this.name = name;
    return this;
  }

  /// Links this reactive object to an owner ID.
  R register(String ownerId) {
    this.ownerId = ownerId;
    return this;
  }

  /// Marks this object as containing sensitive data (redacted in logs).
  R sensitive() {
    this.isSensitive = true;
    return this;
  }
}

/// Interface for objects that require explicit disposal logic.
///
/// Implement this interface for custom classes managed by [Levit] to ensure
/// their resources (streams, connections) are released when the scope closes.
abstract class LevitDisposable {
  /// Releases resources held by this object.
  void dispose();
}
