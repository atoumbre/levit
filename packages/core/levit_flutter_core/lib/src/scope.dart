part of '../levit_flutter_core.dart';

/// An internal widget that propagates the [LevitScope] down the widget tree.
class _ScopeProvider extends InheritedWidget {
  final LevitScope scope;

  const _ScopeProvider({
    required this.scope,
    required super.child,
  });

  static LevitScope? of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_ScopeProvider>()?.scope;
  }

  @override
  bool updateShouldNotify(_ScopeProvider oldWidget) => scope != oldWidget.scope;
}

/// A widget that defines an isolated dependency injection scope bound to its position in the widget tree.
///
/// [LScope] allows for hierarchical dependency management and automatic resource
/// cleanup. When the [LScope] is removed from the widget tree, all non-permanent
/// dependencies registered within it are disposed.
///
/// ### Stability
/// By default, [LScope] is **stable**: it will only be initialized once and will
/// not be recreated even if [dependencyFactory] or [name] changes. To trigger
/// reactive re-initialization, provide a list of [args].
///
/// // Example usage:
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

  @override
  State<LScope> createState() => _LScopeState();

  /// The nearest [LevitScope] from the widget tree.
  static LevitScope? of(BuildContext context) => _ScopeProvider.of(context);
}

class _LScopeState extends State<LScope> {
  late LevitScope _scope;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initScope();
  }

  void _initScope() {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LScope';
    final parentScope = _ScopeProvider.of(context);

    // Create the scope and link to parent if found
    _scope = parentScope != null
        ? parentScope.createScope(scopeName)
        : Levit.createScope(scopeName);

    widget.dependencyFactory?.call(_scope);
    _initialized = true;
  }

  @override
  void didUpdateWidget(LScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

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

/// An asynchronous version of [LScope] that waits for dependencies to initialize.
///
/// [LAsyncScope] creates a new [LevitScope], runs the provided [dependencyFactory],
/// and only renders the [child] once the factory's future completes.
///
/// // Example usage:
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initScope();
  }

  void _initScope() {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LAsyncScope';

    // We use the internal provider to find the parent scope
    final parentScope = _ScopeProvider.of(context);

    // Create the scope and link to parent if found
    _scope = parentScope != null
        ? parentScope.createScope(scopeName)
        : Levit.createScope(scopeName);

    // Start the async initialization
    _initFuture = widget.dependencyFactory(_scope);
    _initialized = true;
  }

  @override
  void didUpdateWidget(LAsyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

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

/// A proxy for accessing Levit dependency injection via [BuildContext].
class LevitProvider {
  final BuildContext _context;

  LevitProvider(this._context);

  /// Resolves a dependency of type [S] or identified by [key] or [tag].
  S find<S>({dynamic key, String? tag}) {
    if (key is LevitState) {
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
      if (key is LevitState) {
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
    if (key is LevitState) {
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
      if (key is LevitState) {
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
    if (key is LevitState) {
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
    if (key is LevitState) {
      final scope = _ScopeProvider.of(_context) ?? Ls.currentScope;
      return key.isInstantiatedIn(scope, tag: tag);
    }
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.isInstantiated<S>(tag: tag);
    }
    return Levit.isInstantiated<S>(tag: tag);
  }

  /// Instantiates and registers a dependency using a [builder].
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
