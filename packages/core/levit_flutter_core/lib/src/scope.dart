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

class LScope extends StatefulWidget {
  /// An optional factory to register dependencies in this scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// The widget subtree that will have access to this scope.
  final Widget child;

  /// A descriptive name for the scope, used in debugging and profiling.
  final String? name;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// If provided, the scope will be recreated if the identity or value
  /// of any element in [args] changes.
  ///
  /// If [args] is `null` (default), the scope is **stable**: it will only be
  /// initialized once and will not be recreated even if [dependencyFactory]
  /// or [name] changes.
  final List<Object?>? args;

  /// Creates a widget-tree-bound dependency scope.
  const LScope({
    super.key,
    this.dependencyFactory,
    required this.child,
    this.name,
    this.args,
  });

  @override
  State<LScope> createState() => _LScopeState();

  /// Retrieves the nearest [LevitScope] from the widget tree.
  static LevitScope? of(BuildContext context) => _ScopeProvider.of(context);
}

class _LScopeState extends State<LScope> {
  late LevitScope _scope;
  bool _initialized = false;

  void _initScope() {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LScope';
    final parentProvider =
        context.getInheritedWidgetOfExactType<_ScopeProvider>();
    final parentScope = parentProvider?.scope;

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
    _initScope();
    return _ScopeProvider(
      scope: _scope,
      child: widget.child,
    );
  }
}

/// An asynchronous version of [LScope] that waits for dependencies to initialize.
///
/// This widget creates a new [LevitScope], runs the provided [dependencyFactory],
/// and only renders the [child] once the factory's future completes.
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
  ///
  /// If provided, the scope will be disposed and recreated (and the factory re-run)
  /// if the identity or value of any element in [args] changes.
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
  void initState() {
    super.initState();
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

/// Helper class for scoped DI access via [BuildContext].
class LevitProvider {
  final BuildContext _context;

  LevitProvider(this._context);

  /// Retrieves a dependency of type [S].
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

  /// Retrieves a dependency, or null if not found.
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

  /// Asynchronously retrieves the registered instance of type [S].
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

  /// Asynchronously retrieves the registered instance of type [S], or null.
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

  /// Returns `true` if type [S] has already been instantiated.
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

  S put<S>(S Function() builder, {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.put<S>(builder, tag: tag, permanent: permanent);
    }
    return Levit.put<S>(builder, tag: tag, permanent: permanent);
  }

  /// Registers an asynchronous [builder] for lazy instantiation.
  Future<S> Function() lazyPutAsync<S>(Future<S> Function() builder,
      {String? tag, bool permanent = false}) {
    final scope = _ScopeProvider.of(_context);
    if (scope != null) {
      return scope.lazyPutAsync<S>(builder, tag: tag, permanent: permanent);
    } else {
      return Levit.lazyPutAsync<S>(builder, tag: tag, permanent: permanent);
    }
  }

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

/// Ergonomic extension to access Levit dependency injection directly from [BuildContext].
extension LevitProviderExtension on BuildContext {
  /// Returns a [LevitProvider] to interact with the nearest active [LevitScope].
  LevitProvider get levit => LevitProvider(this);
}
