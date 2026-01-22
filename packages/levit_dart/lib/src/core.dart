part of '../levit_dart.dart';

/// The central access point for the Levit framework.
///
/// [Levit] provides static methods to manage the application's dependency injection (DI)
/// system and state management lifecycle. It serves as a facade over the active [LevitScope],
/// handling implicit scoping via [Zone] values.
///
/// **Key Responsibilities:**
/// *   **Dependency Management:** Register and retrieve dependencies ([put], [find], [lazyPut]).
/// *   **Scope Management:** Create and manage child scopes ([createScope], [reset]).
/// *   **Middleware Integration:** Register global middlewares for logging and monitoring ([addMiddleware]).
/// *   **Auto-Linking:** Automatically link reactive variables to their controllers ([enableAutoLinking]).
///
/// This class is designed to be used statically. Most operations delegate to the
/// [LevitScope] associated with the current [Zone]. If no specific scope is active,
/// the root scope is used.
class Levit {
  /// The root scope of the application.
  static final LevitScope _root = () {
    return LevitScope.root();
  }();

  static int _activeCaptureScopes = 0;

  /// The internal [Zone] key used to identify the active [LevitScope].
  static final Object zoneScopeKey = Object();

  /// Retrieves the current active [LevitScope].
  ///
  /// This property checks the current [Zone] for an active scope. If none is found,
  /// it returns the global root scope. This allows for implicit scope propagation
  /// through async calls and widget trees (when used with `levit_flutter`).
  static LevitScope get _currentScope {
    final implicit = Zone.current[Levit.zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Registers a dependency instance in the active scope.
  ///
  /// The [builder] is executed immediately to create the instance.
  ///
  /// *   [builder]: A function that returns the dependency instance.
  /// *   [tag]: An optional unique identifier for this dependency.
  /// *   [permanent]: If `true`, the dependency will not be removed when the scope is reset (unless forced).
  ///
  /// Returns the created instance.
  ///
  /// Example:
  /// ```dart
  /// final service = Levit.put(() => MyService());
  /// ```
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return _currentScope.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a lazy dependency builder in the active scope.
  ///
  /// The [builder] is not executed until the dependency is first requested via [find].
  ///
  /// *   [builder]: A function that creates the dependency instance.
  /// *   [tag]: An optional unique identifier.
  /// *   [permanent]: If `true`, the registration persists across resets.
  /// *   [isFactory]: If `true`, the [builder] is executed *every time* [find] is called,
  ///     creating a new instance each time.
  ///
  /// Example:
  /// ```dart
  /// Levit.lazyPut(() => MyService());
  /// ```
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    _currentScope.lazyPut<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Registers an asynchronous lazy dependency builder.
  ///
  /// The [builder] returns a [Future]. Use [findAsync] to retrieve the instance.
  ///
  /// *   [builder]: A function returning a [Future] of the dependency.
  /// *   [tag]: An optional unique identifier.
  /// *   [permanent]: If `true`, the registration persists across resets.
  /// *   [isFactory]: If `true`, the builder is re-executed for every [findAsync] call.
  static void lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    _currentScope.lazyPutAsync<S>(builder,
        tag: tag, permanent: permanent, isFactory: isFactory);
  }

  /// Retrieves a registered dependency of type [S].
  ///
  /// *   [tag]: The unique identifier used at registration.
  ///
  /// Throws a [LevitException] (or standard [Exception]) if the dependency is not found.
  ///
  /// Example:
  /// ```dart
  /// final service = Levit.find<MyService>();
  /// ```
  static S find<S>({String? tag}) {
    return _currentScope.find<S>(tag: tag);
  }

  /// Retrieves a registered dependency of type [S], or returns `null` if not found.
  ///
  /// *   [tag]: The unique identifier used at registration.
  static S? findOrNull<S>({String? tag}) {
    return _currentScope.findOrNull<S>(tag: tag);
  }

  /// Asynchronously retrieves a registered dependency of type [S].
  ///
  /// This waits for the [Future] provided in [lazyPutAsync] to complete.
  ///
  /// *   [tag]: The unique identifier used at registration.
  ///
  /// Throws if the dependency is not found.
  static Future<S> findAsync<S>({String? tag}) {
    return _currentScope.findAsync<S>(tag: tag);
  }

  /// Asynchronously retrieves a registered dependency of type [S], or returns `null` if not found.
  ///
  /// *   [tag]: The unique identifier used at registration.
  static Future<S?> findOrNullAsync<S>({String? tag}) {
    return _currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Checks if a dependency of type [S] is registered in the active scope or its parents.
  ///
  /// *   [tag]: The unique identifier used at registration.
  ///
  /// Returns `true` if registered.
  static bool isRegistered<S>({String? tag}) {
    return _currentScope.isRegistered<S>(tag: tag);
  }

  /// Checks if a dependency of type [S] has been instantiated (created).
  ///
  /// *   [tag]: The unique identifier used at registration.
  ///
  /// Returns `true` if the instance exists in memory.
  static bool isInstantiated<S>({String? tag}) {
    return _currentScope.isInstantiated<S>(tag: tag);
  }

  /// Deletes a registered dependency of type [S] from the active scope.
  ///
  /// If the instance exists and implements [LevitScopeDisposable] (or has an `onClose` method via [LevitController]),
  /// it will be disposed.
  ///
  /// *   [tag]: The unique identifier used at registration.
  /// *   [force]: If `true`, deletes the dependency even if it was marked as `permanent`.
  ///
  /// Returns `true` if the dependency was found and deleted.
  static bool delete<S>({String? tag, bool force = false}) {
    return _currentScope.delete<S>(tag: tag, force: force);
  }

  /// Resets the active scope, removing all non-permanent dependencies.
  ///
  /// *   [force]: If `true`, removes *all* dependencies, including permanent ones.
  static void reset({bool force = false}) {
    _currentScope.reset(force: force);
  }

  /// Creates a new child scope from the current active scope.
  ///
  /// Child scopes inherit dependencies from their parent but can override them.
  /// They provide an isolated environment for module-specific dependencies.
  ///
  /// *   [name]: A descriptive name for the scope (useful for debugging).
  ///
  /// Returns the newly created [LevitScope].
  static LevitScope createScope(String name) {
    return _currentScope.createScope(name);
  }

  /// The number of dependencies registered in the current active scope.
  static int get registeredCount => _currentScope.registeredCount;

  /// A list of all keys (type + tag) registered in the current active scope.
  static List<String> get registeredKeys => _currentScope.registeredKeys;

  /// Adds a middleware for dependency injection events.
  ///
  /// See [LevitScopeMiddleware] for details on available hooks.
  static void addDependencyMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.addMiddleware(middleware);
  }

  /// Removes a dependency injection middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.removeMiddleware(middleware);
  }

  /// Adds a middleware for reactive state events.
  ///
  /// See [LevitReactiveMiddleware] for details on available hooks.
  static void addStateMiddleware(LevitMiddleware middleware) {
    _middlewares.add(middleware);
    Lx.addMiddleware(middleware);
  }

  /// Removes a reactive state middleware.
  static void removeStateMiddleware(LevitMiddleware middleware) {
    _middlewares.remove(middleware);
    Lx.removeMiddleware(middleware);
  }

  static final List<LevitMiddleware> _middlewares = [];

  /// Registers a global middleware for both state and DI events.
  ///
  /// This is useful for comprehensive logging or developer tools.
  static void addMiddleware(LevitMiddleware middleware) {
    _middlewares.add(middleware);
    Lx.addMiddleware(middleware);
    LevitScope.addMiddleware(middleware);
  }

  /// Removes a global middleware.
  static void removeMiddleware(LevitMiddleware middleware) {
    _middlewares.remove(middleware);
    Lx.removeMiddleware(middleware);
    LevitScope.removeMiddleware(middleware);
  }

  /// Notifies middlewares that a reactive object has been registered with an owner.
  static void _notifyRegister(LxReactive reactive, String ownerId) {
    for (final mw in _middlewares) {
      mw.onReactiveRegister(reactive, ownerId);
    }
  }

  static final Object _captureKey = Object();

  /// The internal key used for capturing reactive objects in the current [Zone].
  @visibleForTesting
  static Object get captureKey => _captureKey;

  static final _autoLinkMiddleware = _AutoLinkMiddleware();

  /// Enables "Auto-Linking" of reactive variables to controllers.
  ///
  /// When enabled, any [Lx] variable created during the initialization of a
  /// [LevitController] (specifically within [LevitController.onInit] or the builder passed to [put])
  /// is automatically linked to that controller for lifecycle management.
  static void enableAutoLinking() {
    Lx.addMiddleware(_autoLinkMiddleware);
    LevitScope.addMiddleware(_AutoDisposeMiddleware());
  }

  /// Disables "Auto-Linking".
  static void disableAutoLinking() {
    Lx.removeMiddleware(_autoLinkMiddleware);
    LevitScope.removeMiddleware(_AutoDisposeMiddleware());
  }
}

class _AutoLinkMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive)? get onInit => (reactive) {
        if (Levit._activeCaptureScopes == 0) return;
        final captureList = Zone.current[Levit._captureKey];
        if (captureList is List) {
          captureList.add(reactive);
        }
      };
}

class _AutoDisposeMiddleware extends LevitScopeMiddleware {
  @override
  S Function() onCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return _createCaptureHook(builder, key);
  }

  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return _createCaptureHookInit(onInit, key, instance);
  }
}

S Function() _createCaptureHook<S>(
  S Function() builder,
  String key,
) {
  return () {
    // Fast path: Skip Zone overhead when no middlewares are listening
    // and we're not already inside a capture scope
    final parentList = Zone.current[Levit._captureKey] as List<LxReactive>?;
    if (parentList == null && !LevitReactiveMiddleware.hasInitMiddlewares) {
      final instance = builder();
      // Still process for auto-dispose registration if it's a controller
      if (instance is LevitController) {
        _processInstance(instance, <LxReactive>[], key);
      }
      return instance;
    }

    // Slow path: Full Zone-based capture
    final captured = <LxReactive>[];
    final proxyList = parentList != null
        ? _ChainedCaptureList(captured, parentList)
        : captured;

    Levit._activeCaptureScopes++;
    try {
      final instance = runZoned(
        builder,
        zoneValues: {Levit._captureKey: proxyList},
      );

      if (instance is Future) {
        instance
            .then((resolvedInstance) {
              _processInstance(resolvedInstance, captured, key);
            })
            .catchError((_) {})
            .whenComplete(() {
              Levit._activeCaptureScopes--;
            });
        return instance;
      } else {
        _processInstance(instance, captured, key);
        Levit._activeCaptureScopes--;
        return instance;
      }
    } catch (e) {
      Levit._activeCaptureScopes--;
      rethrow;
    }
  };
}

void Function() _createCaptureHookInit<S>(
  void Function() onInit,
  String key,
  S instance,
) {
  return () {
    // Determine the capture list implementation
    List<LxReactive> captured;
    if (instance is LevitController) {
      // Use "Live Capture" for controllers.
      // This immediately registers and auto-disposes variables as they are created,
      // creating a robust solution for async onInit scenarios.
      captured = _LiveCaptureList(instance, key);
    } else {
      captured = <LxReactive>[];
    }

    final parentList = Zone.current[Levit._captureKey] as List<LxReactive>?;
    final proxyList = parentList != null
        ? _ChainedCaptureList(captured, parentList)
        : captured;

    Levit._activeCaptureScopes++;
    try {
      // Cast to dynamic to allow capturing return value (Future or null)
      // from a statically typed void Function().
      final dynamic result = runZoned(
        () => (onInit as dynamic)(),
        zoneValues: {Levit._captureKey: proxyList},
      );

      if (result is Future) {
        result.whenComplete(() {
          Levit._activeCaptureScopes--;
        });
      } else {
        Levit._activeCaptureScopes--;
      }
    } catch (e) {
      Levit._activeCaptureScopes--;
      rethrow;
    }
  };
}

void _processInstance(dynamic instance, List<LxReactive> captured, String key) {
  if (instance is LevitController) {
    for (final reactive in captured) {
      // Check if already registered (by Live Capture) to avoid double logging if mixed
      if (reactive.ownerId == null) {
        reactive.ownerId = key;
        Levit._notifyRegister(reactive, key);
        instance.autoDispose(reactive);
      }
    }
  }
}

class _LiveCaptureList extends ListBase<LxReactive> {
  final List<LxReactive> _inner = [];
  final LevitController _controller;
  final String _key;

  _LiveCaptureList(this._controller, this._key);

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  LxReactive operator [](int index) => _inner[index];

  @override
  void operator []=(int index, LxReactive value) {
    _inner[index] = value;
  }

  @override
  void add(LxReactive element) {
    _inner.add(element);

    // Live Capture Logic
    // We register immediately to avoid race conditions in synchronous tests.
    // While this means `.named()` might not have run yet (so name might be null in logs),
    // correctness of registration takes precedence over debug log aesthetics.
    if (element.ownerId == null) {
      element.ownerId = _key;
      Levit._notifyRegister(element, _key);
      _controller.autoDispose(element);
    }
  }
}

class _ChainedCaptureList extends ListBase<LxReactive> {
  final List<LxReactive> _inner;
  final List<LxReactive> _parent;

  _ChainedCaptureList(this._inner, this._parent);

  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  LxReactive operator [](int index) => _inner[index];

  @override
  void operator []=(int index, LxReactive value) {
    _inner[index] = value;
  }

  @override
  void add(LxReactive element) {
    _inner.add(element);
    _parent.add(element);
  }
}
