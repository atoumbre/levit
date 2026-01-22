part of '../levit_dart.dart';

/// The primary entry point for managing dependencies and scopes in Levit.
///
/// [Levit] provides a unified, static interface for interacting with the
/// dependency injection (DI) system. It simplifies access to the current
/// [LevitScope] by using [Zone]-based implicit propagation.
///
/// In a Levit application, dependencies are stored within a [LevitScope].
/// By default, [Levit] operations target the root scope. However, when code
/// is executed within a nested scope using [LevitScope.run], this class
/// automatically detects and targets that active scope.
///
/// This "ambient" scope behavior allows components to find their dependencies
/// without requiring manual scope passing, while still supporting isolation
/// for features like modularity or testing.
class Levit {
  static final LevitScope _root = () {
    return LevitScope.root();
  }();

  static int _activeCaptureScopes = 0;

  /// The internal [Zone] key used to find the active scope.
  static final Object zoneScopeKey = Object();

  /// Retrieves the current active [LevitScope].
  ///
  /// Returns the scope associated with the current [Zone], or the root scope
  /// if no explicit scope is active.
  static LevitScope get _currentScope {
    final implicit = Zone.current[Levit.zoneScopeKey];
    if (implicit is LevitScope) return implicit;
    return _root;
  }

  /// Instantiates and registers a dependency using a [builder].
  ///
  /// The [builder] is executed immediately. If [Levit.enableAutoLinking] is
  /// active, any reactive variables (like [Lx]) created during execution are
  /// automatically captured and linked to the resulting instance for cleanup.
  ///
  /// * [builder]: A function that creates the dependency instance.
  /// * [tag]: Optional unique identifier to allow multiple instances of the same type [S].
  /// * [permanent]: If `true`, this instance survives a non-forced [reset].
  ///
  /// Returns the created instance of type [S].
  static S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    return _currentScope.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  ///
  /// * [builder]: A function that creates the dependency instance.
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration persists through a [reset].
  /// * [isFactory]: If `true`, a new instance is created every time [find] is called.
  static void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    _currentScope.lazyPut<S>(builder,
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
  static void lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    _currentScope.lazyPutAsync<S>(builder,
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
    return _currentScope.find<S>(tag: tag);
  }

  /// Retrieves the registered instance of type [S], or returns `null` if not found.
  ///
  /// * [tag]: The unique identifier used during registration.
  static S? findOrNull<S>({String? tag}) {
    return _currentScope.findOrNull<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S].
  ///
  /// Useful for dependencies registered via [lazyPutAsync].
  ///
  /// * [tag]: The unique identifier used during registration.
  ///
  /// Throws an [Exception] if no registration is found.
  static Future<S> findAsync<S>({String? tag}) {
    return _currentScope.findAsync<S>(tag: tag);
  }

  /// Asynchronously retrieves the registered instance of type [S], or returns `null`.
  ///
  /// * [tag]: The unique identifier used during registration.
  static Future<S?> findOrNullAsync<S>({String? tag}) {
    return _currentScope.findOrNullAsync<S>(tag: tag);
  }

  /// Returns `true` if type [S] is registered in the current or any parent scope.
  static bool isRegistered<S>({String? tag}) {
    return _currentScope.isRegistered<S>(tag: tag);
  }

  /// Returns `true` if type [S] has already been instantiated.
  static bool isInstantiated<S>({String? tag}) {
    return _currentScope.isInstantiated<S>(tag: tag);
  }

  /// Removes the registration for [S] and disposes of the instance.
  ///
  /// If the instance implements [LevitScopeDisposable], its `onClose` method is called.
  ///
  /// * [tag]: The unique identifier used during registration.
  /// * [force]: If `true`, deletes even if the dependency was marked as `permanent`.
  ///
  /// Returns `true` if a registration was found and removed.
  static bool delete<S>({String? tag, bool force = false}) {
    return _currentScope.delete<S>(tag: tag, force: force);
  }

  /// Disposes of all non-permanent dependencies in the current scope.
  ///
  /// * [force]: If `true`, also disposes of permanent dependencies.
  static void reset({bool force = false}) {
    _currentScope.reset(force: force);
  }

  /// Creates a new child scope branching from the current active scope.
  ///
  /// child scopes can override parent dependencies and provide their own
  /// isolated lifecycle.
  ///
  /// * [name]: A descriptive name for the scope (used in profiling and logs).
  static LevitScope createScope(String name) {
    return _currentScope.createScope(name);
  }

  /// The total number of dependencies registered in the current active scope.
  static int get registeredCount => _currentScope.registeredCount;

  /// A list of all registration keys (type + tag) in the current active scope.
  static List<String> get registeredKeys => _currentScope.registeredKeys;

  /// Adds a global middleware for receiving dependency injection events.
  static void addDependencyMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.addMiddleware(middleware);
  }

  /// Removes a DI middleware.
  static void removeDependencyMiddleware(LevitScopeMiddleware middleware) {
    LevitScope.removeMiddleware(middleware);
  }

  /// Adds a middleware to the list of active middlewares.
  static void addStateMiddleware(LevitMiddleware middleware) {
    _middlewares.add(middleware);
    Lx.addMiddleware(middleware);
  }

  /// Removes a middleware from the list of active middlewares.
  static void removeStateMiddleware(LevitMiddleware middleware) {
    _middlewares.remove(middleware);
    Lx.removeMiddleware(middleware);
  }

  static final List<LevitMiddleware> _middlewares = [];

  /// Registers a [middleware] to intercept both state changes and DI events.
  ///
  /// Middlewares can be used for logging, persistence, or implementing
  /// advanced features like Time Travel.
  static void addMiddleware(LevitMiddleware middleware) {
    _middlewares.add(middleware);
    Lx.addMiddleware(middleware);
    LevitScope.addMiddleware(middleware);
  }

  /// Un-registers a previously added [middleware].
  static void removeMiddleware(LevitMiddleware middleware) {
    _middlewares.remove(middleware);
    Lx.removeMiddleware(middleware);
    LevitScope.removeMiddleware(middleware);
  }

  /// Internal: Notifies middlewares that a reactive object has been registered.
  static void _notifyRegister(LxReactive reactive, String ownerId) {
    for (final mw in _middlewares) {
      mw.onReactiveRegister(reactive, ownerId);
    }
  }

  static final Object _captureKey = Object();

  /// The key used to capture reactive objects in the current [Zone].
  @visibleForTesting
  static Object get captureKey => _captureKey;

  static final _autoLinkMiddleware = _AutoLinkMiddleware();

  /// Enables the "Auto-Linking" feature.
  ///
  /// When enabled, any [Lx] variable created inside a [Levit.put] builder or
  /// [LevitController.onInit] is automatically registered for cleanup with
  /// its parent controller.
  static void enableAutoLinking() {
    Lx.addMiddleware(_autoLinkMiddleware);
    LevitScope.addMiddleware(_AutoDisposeMiddleware());
  }

  /// Disables the "Auto-Linking" feature.
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
    Levit._notifyRegister(this, ownerId);
    return this;
  }
}
