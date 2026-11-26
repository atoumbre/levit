part of '../levit_flutter_core.dart';

/// A widget that creates a [LevitScope] tied to the widget tree.
///
/// Use [LScope] to provide dependencies for a specific subtree.
/// The scope is automatically closed when the widget is unmounted.
///
/// ```dart
/// LScope(
///   configure: (scope) => scope.put<MyController>(() => MyController()),
///   child: const MyPage(),
/// )
/// ```
///
/// {@category Flutter Widgets & Interop}
class LScope extends StatefulWidget {
  /// Optional callback to register dependencies in this scope.
  final void Function(LevitScope scope)? configure;

  /// The widget subtree that will have access to this scope.
  final Widget child;

  /// A descriptive name for the scope (used in profiling and logs).
  ///
  /// When omitted, Levit generates a unique name from the widget runtime type
  /// and state identity (for example `LScope@123456`). Set an explicit [name]
  /// only when you want a stable label for diagnostics.
  final String? name;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// If provided, the scope is recreated whenever the list length or any
  /// element value changes according to `!=`.
  final List<Object?>? args;

  /// Optional completion/retry handle; must remain stable while mounted.
  final LevitScopeLifecycleController? lifecycle;

  /// Rendered while the previous scope drains during replacement.
  final Widget Function(BuildContext context)? loading;

  /// Rendered when initialization or replacement cleanup fails.
  final Widget Function(BuildContext context, Object error)? error;

  /// Creates a widget-tree-bound dependency scope.
  const LScope({
    super.key,
    this.configure,
    required this.child,
    this.name,
    this.args,
    this.lifecycle,
    this.loading,
    this.error,
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
      configure: (s) {
        s.put<S>(builder, tag: tag, permanent: permanent);
      },
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
      configure: (s) {
        s.lazyPut<S>(
          builder,
          tag: tag,
          permanent: permanent,
          isFactory: isFactory,
        );
      },
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
      configure: (s) {
        s.lazyPutAsync<S>(
          builder,
          tag: tag,
          permanent: permanent,
          isFactory: isFactory,
        );
      },
      child: child,
    );
  }

  /// Executes [builder] with the nearest [LScope] bound synchronously as
  /// [Ls.currentScope].
  ///
  /// This bridges Widget-tree scoping ([InheritedWidget]) and static scoping
  /// without allocating a new [Zone], allowing [Levit.find] to resolve from
  /// the nearest [LScope] during synchronous widget builds.
  static R runBridged<R>(BuildContext context, R Function() builder) {
    final scope = _ScopeProvider.of(context);
    // Bridge widget-tree scope synchronously for `Levit.find` consistency.
    if (scope != null && !identical(scope, Ls.currentScope)) {
      return LsSpi.runSyncWithScope(scope, builder);
    }
    return builder();
  }

  /// Captures the nearest [LevitScope] from [context] and re-provides it to
  /// another subtree.
  ///
  /// Useful for dialogs, bottom sheets, and other overlay routes that are no
  /// longer descendants of the originating [LScope] widget tree. When using
  /// `levit_flutter`, prefer `showLevitDialog` and `showLevitModalBottomSheet`.
  ///
  /// Note: [capture] borrows the scope without extending its lifetime. If the
  /// originating [LScope] unmounts while the overlay remains open, the captured
  /// scope still disposes. If no local scope is found, [child] is returned
  /// unchanged.
  ///
  /// ```dart
  /// final captured = LScope.capture(context, child: const ConfirmDialog());
  /// await showDialog<void>(context: context, builder: (_) => captured);
  /// ```
  static Widget capture(BuildContext context, {required Widget child}) {
    final scope = _ScopeProvider.of(context);
    if (scope == null) return child;
    return _CapturedScope(scope: scope, child: child);
  }

  @override
  State<LScope> createState() => _LScopeState();

  /// Returns the nearest [LevitScope] from the widget tree, or `null` if none
  /// exists.
  ///
  /// When [listen] is `true`, registers a widget dependency so the caller
  /// rebuilds if the ancestor scope instance changes.
  static LevitScope? of(BuildContext context, {bool listen = false}) =>
      _ScopeProvider.of(context, listen: listen);
}

class _LScopeState extends State<LScope> {
  late final LevitScopeLifecycleController _lifecycle;
  LevitScope? _parent;
  bool _configured = false;
  LevitScope? _renderedScope;
  Object? _renderedError;
  bool _hasRendered = false;

  @override
  void initState() {
    super.initState();
    LevitFlutter.ensureInitialized();
    _lifecycle = widget.lifecycle ?? LevitScopeLifecycleController();
    _lifecycle.addListener(_changed);
  }

  void _changed() {
    if (!mounted || !_hasRendered) return;
    if (identical(_lifecycle.scope, _renderedScope) &&
        identical(_lifecycle.error, _renderedError)) {
      return;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = _ScopeProvider.of(context, listen: true) ?? Ls.currentScope;
    if (!_configured || !identical(parent, _parent)) {
      _parent = parent;
      _configure();
    }
  }

  void _configure() {
    _configured = true;
    final configure = widget.configure;
    unawaited(
      _lifecycle.replace(
        parent: _parent!,
        name: widget.name ?? _uniqueScopeName(widget, this),
        initialize: (scope) => configure?.call(scope),
      ),
    );
  }

  @override
  void didUpdateWidget(LScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lifecycle, oldWidget.lifecycle)) {
      throw StateError(
        'Keep the lifecycle controller stable or use a new widget key.',
      );
    }
    if (widget.name != oldWidget.name ||
        !_scopeArgsMatch(widget.args, oldWidget.args)) {
      _configure();
    }
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_changed);
    unawaited(_lifecycle.close().catchError(_reportScopeCleanupError));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _hasRendered = true;
    final error = _lifecycle.error;
    final scope = _lifecycle.scope;
    _renderedError = error;
    _renderedScope = scope;
    if (error != null) {
      return widget.error?.call(context, error) ??
          Text('Scope error: $error', textDirection: TextDirection.ltr);
    }
    if (scope != null) return _ScopeProvider(scope: scope, child: widget.child);
    return widget.loading?.call(context) ?? const SizedBox.shrink();
  }
}

/// An asynchronous version of [LScope].
///
/// Initializes the scope using an asynchronous [configure] callback and
/// only renders [child] when initialization completes.
///
/// ```dart
/// LAsyncScope(
///   configure: (scope) async {
///     scope.lazyPutAsync(() => DataService.init());
///     await scope.findAsync<DataService>();
///   },
///   loading: (context) => const LoadingSpinner(),
///   child: const DataPage(),
/// )
/// ```
///
/// {@category Flutter Widgets & Interop}
class LAsyncScope extends StatefulWidget {
  /// An async callback to register dependencies.
  /// The child will not render until this Future completes.
  final FutureOr<void> Function(LevitScope scope) configure;

  /// The widget subtree to render after initialization.
  final Widget child;

  /// A descriptive name for the scope.
  ///
  /// When omitted, Levit generates a unique name from the widget runtime type
  /// and state identity. Set an explicit [name] only when you want a stable
  /// label for diagnostics.
  final String? name;

  /// Optional builder for the loading state. Defaults to `SizedBox.shrink()`.
  final Widget Function(BuildContext context)? loading;

  /// Optional builder for the error state. Defaults to a [Text] describing the
  /// error.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  final List<Object?>? args;

  /// Optional completion/retry handle; must remain stable while mounted.
  final LevitScopeLifecycleController? lifecycle;

  /// Creates an asynchronously initialized widget-tree-bound dependency scope.
  const LAsyncScope({
    super.key,
    required this.configure,
    required this.child,
    this.name,
    this.loading,
    this.error,
    this.args,
    this.lifecycle,
  });

  @override
  State<LAsyncScope> createState() => _LAsyncScopeState();
}

class _LAsyncScopeState extends State<LAsyncScope> {
  late final LevitScopeLifecycleController _lifecycle;
  LevitScope? _parent;
  bool _configured = false;
  LevitScope? _renderedScope;
  Object? _renderedError;
  bool _hasRendered = false;

  @override
  void initState() {
    super.initState();
    LevitFlutter.ensureInitialized();
    _lifecycle = widget.lifecycle ?? LevitScopeLifecycleController();
    _lifecycle.addListener(_changed);
  }

  void _changed() {
    if (!mounted || !_hasRendered) return;
    if (identical(_lifecycle.scope, _renderedScope) &&
        identical(_lifecycle.error, _renderedError)) {
      return;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = _ScopeProvider.of(context, listen: true) ?? Ls.currentScope;
    if (!_configured || !identical(parent, _parent)) {
      _parent = parent;
      _configure();
    }
  }

  void _configure() {
    _configured = true;
    final configure = widget.configure;
    unawaited(
      _lifecycle.replace(
        parent: _parent!,
        name: widget.name ?? _uniqueScopeName(widget, this),
        initialize: (scope) => configure(scope),
      ),
    );
  }

  @override
  void didUpdateWidget(LAsyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lifecycle, oldWidget.lifecycle)) {
      throw StateError(
        'Keep the lifecycle controller stable or use a new widget key.',
      );
    }
    if (widget.name != oldWidget.name ||
        !_scopeArgsMatch(widget.args, oldWidget.args)) {
      _configure();
    }
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_changed);
    unawaited(_lifecycle.close().catchError(_reportScopeCleanupError));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _hasRendered = true;
    final error = _lifecycle.error;
    final scope = _lifecycle.scope;
    _renderedError = error;
    _renderedScope = scope;
    if (error != null) {
      return widget.error?.call(context, error) ??
          Text('Scope error: $error', textDirection: TextDirection.ltr);
    }
    if (scope != null) return _ScopeProvider(scope: scope, child: widget.child);
    return widget.loading?.call(context) ?? const SizedBox.shrink();
  }
}
