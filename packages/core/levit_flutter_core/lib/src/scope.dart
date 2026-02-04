part of '../levit_flutter_core.dart';

/// An internal widget that propagates the [LevitScope] down the widget tree.
class _ScopeProvider extends InheritedWidget {
  final LevitScope scope;

  const _ScopeProvider({
    required this.scope,
    required super.child,
  });

  static LevitScope? of(BuildContext context, {bool listen = false}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_ScopeProvider>()
        : context.getInheritedWidgetOfExactType<_ScopeProvider>();
    return provider?.scope;
  }

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) => scope != oldWidget.scope;
}

/// A widget that creates a [LevitScope] tied to the widget tree.
///
/// Use [LScope] to provide dependencies for a specific subtree.
/// The scope is automatically closed when the widget is unmounted.
///
/// Example:
/// ```dart
/// LScope(
///   dependencyFactory: (scope) => scope.put(() => MyController()),
///   child: const MyPage(),
/// )
/// ```
class LScope extends StatefulWidget {
  /// An optional factory to register dependencies in this scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// The widget subtree that will have access to this scope.
  final Widget child;

  /// A descriptive name for the scope (used in profiling and logs).
  final String? name;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// If provided, the scope will be recreated if the identity or value
  /// of any element changes.
  final List<Object?>? args;

  /// Creates a widget-tree-bound dependency scope.
  const LScope({
    super.key,
    this.dependencyFactory,
    required this.child,
    this.name,
    this.args,
  });

  /// A shorthand for creating a scope and immediately registering a dependency.
  static LScope put<S>(
    S Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    List<Object?>? args,
  }) {
    return LScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) =>
          s.put<S>(builder, tag: tag, permanent: permanent),
      child: child,
    );
  }

  /// A shorthand for creating a scope and registering a lazy dependency.
  static LScope lazyPut<S>(
    S Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    bool isFactory = false,
    List<Object?>? args,
  }) {
    return LScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) => s.lazyPut<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory),
      child: child,
    );
  }

  /// A shorthand for creating a scope and registering an async lazy dependency.
  static LScope lazyPutAsync<S>(
    Future<S> Function() builder, {
    Key? key,
    required Widget child,
    String? name,
    String? tag,
    bool permanent = false,
    bool isFactory = false,
    List<Object?>? args,
  }) {
    return LScope(
      key: key,
      name: name,
      args: args,
      dependencyFactory: (s) => s.lazyPutAsync<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory),
      child: child,
    );
  }

  /// Executes [builder] within the [Zone] of the nearest [LScope].
  ///
  /// This bridges the gap between Widget-tree scoping ([InheritedWidget]) and
  /// static scoping ([Zone]), allowing [Levit.find] to work correctly.
  static R runBridged<R>(BuildContext context, R Function() builder) {
    final scope = _ScopeProvider.of(context);
    // If the widget scope differs from the current Zone scope, we bridge it.
    if (scope != null && scope != Ls.currentScope) {
      return scope.run(builder);
    }
    return builder();
  }

  @override
  State<LScope> createState() => _LScopeState();

  /// The nearest [LevitScope] from the widget tree.
  static LevitScope? of(BuildContext context, {bool listen = false}) =>
      _ScopeProvider.of(context, listen: listen);
}

class _LScopeState extends State<LScope> {
  late LevitScope _scope;
  bool _initialized = false;
  LevitScope? _parentScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newParent = _ScopeProvider.of(context, listen: true);
    if (_initialized && !identical(_parentScope, newParent)) {
      _scope.dispose();
      _initialized = false;
    }
    _initScope();
  }

  void _initScope() {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LScope';
    final parentScope = _ScopeProvider.of(context);
    _parentScope = parentScope;

    // Create the scope and link to parent if found
    _scope = parentScope != null
        ? parentScope.createScope(scopeName)
        : Levit.createScope(scopeName);

    try {
      widget.dependencyFactory?.call(_scope);
      _initialized = true;
    } catch (_) {
      _scope.dispose();
      rethrow;
    }
  }

  @override
  void didUpdateWidget(LScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

    if (widget.name != oldWidget.name) {
      shouldReset = true;
    }

    if (widget.args != null || oldWidget.args != null) {
      if (!_argsMatch(widget.args, oldWidget.args)) {
        shouldReset = true;
      }
    }

    if (shouldReset) {
      _scope.dispose();
      _initialized = false;
      _initScope();
    }
  }

  bool _argsMatch(List<Object?>? a, List<Object?>? b) {
    if (a == null || b == null) return identical(a, b);
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ScopeProvider(
      scope: _scope,
      child: widget.child,
    );
  }
}

/// An asynchronous version of [LScope].
///
/// Initializes the scope using an asynchronous [dependencyFactory] and
/// only renders [child] when initialization completes.
///
/// Example:
/// ```dart
/// LAsyncScope(
///   dependencyFactory: (scope) async {
///     await scope.putAsync(() => DataService.init());
///   },
///   loading: (context) => const LoadingSpinner(),
///   child: const DataPage(),
/// )
/// ```
class LAsyncScope extends StatefulWidget {
  /// An async factory to register dependencies.
  /// The child will not render until this Future completes.
  final Future<dynamic> Function(LevitScope scope) dependencyFactory;

  /// The widget subtree to render after initialization.
  final Widget child;

  /// A descriptive name for the scope.
  final String? name;

  /// Optional builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Optional builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  final List<Object?>? args;

  const LAsyncScope({
    super.key,
    required this.dependencyFactory,
    required this.child,
    this.name,
    this.loading,
    this.error,
    this.args,
  });

  @override
  State<LAsyncScope> createState() => _LAsyncScopeState();
}

class _LAsyncScopeState extends State<LAsyncScope> {
  late LevitScope _scope;
  late Future<void> _initFuture;

  // Track initialization to prevent re-running logic on standard rebuilds
  bool _initialized = false;
  LevitScope? _parentScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newParent = _ScopeProvider.of(context, listen: true);
    if (_initialized && !identical(_parentScope, newParent)) {
      _scope.dispose();
      _initialized = false;
    }
    _initScope();
  }

  void _initScope() {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LAsyncScope';

    // We use the internal provider to find the parent scope
    final parentScope = _ScopeProvider.of(context);
    _parentScope = parentScope;

    // Create the scope and link to parent if found
    _scope = parentScope != null
        ? parentScope.createScope(scopeName)
        : Levit.createScope(scopeName);

    // Start the async initialization
    _initFuture = widget.dependencyFactory(_scope).catchError((e) {
      _scope.dispose();
      throw e;
    });
    _initialized = true;
  }

  @override
  void didUpdateWidget(LAsyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

    if (widget.name != oldWidget.name) {
      shouldReset = true;
    }

    // Check if arguments changed to trigger a re-init
    if (widget.args != null || oldWidget.args != null) {
      if (!_argsMatch(widget.args, oldWidget.args)) {
        shouldReset = true;
      }
    }

    if (shouldReset) {
      _scope.dispose();
      _initialized = false;
      _initScope();
    }
  }

  bool _argsMatch(List<Object?>? a, List<Object?>? b) {
    if (a == null || b == null) return identical(a, b);
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _scope.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // 1. Handle Error
        if (snapshot.hasError) {
          return widget.error?.call(context, snapshot.error!) ??
              Center(
                child: Text(
                  'Scope Initialization Error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
        }

        // 2. Handle Success
        if (snapshot.connectionState == ConnectionState.done) {
          // Inject the initialized scope into the tree
          return _ScopeProvider(
            scope: _scope,
            child: widget.child,
          );
        }

        // 3. Handle Loading
        return widget.loading?.call(context) ?? const SizedBox.shrink();
      },
    );
  }
}

/// Gateway for finding dependencies from [BuildContext].
///
/// Proxies calls to the nearest [LScope] found in the widget tree.
/// If no local scope is found, it falls back to the global [Levit] scope.
class LevitProvider {
  final BuildContext _context;

  LevitProvider(this._context);

  /// Resolves a dependency of type [S] or identified by [key] or [tag].
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.findIn(scope, tag: tag) as S;
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.find<S>(tag: tag);
    }
    return Levit.find<S>(tag: tag);
  }

  /// Resolves a dependency, or null if not found.
  S? findOrNull<S>({dynamic key, String? tag}) {
    try {
      if (key is LevitStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        return key.findIn(scope, tag: tag) as S?;
      }
      final scope = _ScopeProvider.of(_context);
      if (scope != null) {
        return scope.findOrNull<S>(tag: tag);
      }
      return Levit.findOrNull<S>(tag: tag);
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously resolves a dependency of type [S] or identified by [key] or [tag].
  Future<S> findAsync<S>({dynamic key, String? tag}) async {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      final result = await key.findAsyncIn(scope, tag: tag);
      if (result is Future) return await result as S;
      return result as S;
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return await scope.findAsync<S>(tag: tag);
    }
    return await Levit.findAsync<S>(tag: tag);
  }

  /// Asynchronously resolves a dependency, or null if not found.
  Future<S?> findOrNullAsync<S>({dynamic key, String? tag}) async {
    try {
      if (key is LevitStore) {
        final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
        final result = await key.findAsyncIn(scope, tag: tag);
        if (result is Future) return await result as S?;
        return result as S?;
      }
      final scope = _ScopeProvider.of(_context);
      if (scope != null) {
        return await scope.findOrNullAsync<S>(tag: tag);
      }
      return await Levit.findOrNullAsync<S>(tag: tag);
    } catch (_) {
      return null;
    }
  }

  /// Whether type [S] is registered in the current or any parent scope.
  bool isRegistered<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isRegisteredIn(scope, tag: tag);
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isRegistered<S>(tag: tag);
    }
    return Levit.isRegistered<S>(tag: tag);
  }

  /// Whether type [S] has already been instantiated.
  bool isInstantiated<S>({dynamic key, String? tag}) {
    if (key is LevitStore) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isInstantiatedIn(scope, tag: tag);
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isInstantiated<S>(tag: tag);
    }
    return Levit.isInstantiated<S>(tag: tag);
  }

  /// Instantiates and registers a dependency.
  ///
  /// Registers within the nearest [LScope] if available; otherwise uses global [Levit].
  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers a [builder] that will be executed only when the dependency is first requested.
  void lazyPut<S>(S Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      scope.lazyPut<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory);
    } else {
      Levit.lazyPut<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory);
    }
  }

  /// Registers an asynchronous [builder] for lazy instantiation.
  Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false, bool isFactory = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.lazyPutAsync<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory);
    } else {
      return Levit.lazyPutAsync<S>(builder,
          tag: tag, permanent: permanent, isFactory: isFactory);
    }
  }

  /// Resolves the dependency, or registers it via [builder] if not found.
  S putOrFind<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      final instance = scope.findOrNull<S>(tag: tag);
      if (instance != null) return instance;
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }

    final instance = Levit.findOrNull<S>(tag: tag);
    if (instance != null) return instance;
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }
}

/// Extensions to access Levit dependency injection directly from [BuildContext].
extension LevitProviderExtension on BuildContext {
  /// A [LevitProvider] to interact with the nearest active [LevitScope].
  LevitProvider get levit => LevitProvider(this);
}
