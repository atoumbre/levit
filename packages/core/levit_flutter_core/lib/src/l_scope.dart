part of '../levit_flutter_core.dart';

/// A widget that creates a [LevitScope] tied to the widget tree.
///
/// Use [LScope] to provide dependencies for a specific subtree.
/// The scope is automatically closed when the widget is unmounted.
///
/// // Example usage:
/// ```dart
/// LScope(
///   configure: (scope) => scope.put<MyController>(() => MyController()),
///   child: const MyPage(),
/// )
/// ```
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
  /// If provided, the scope will be recreated if the identity or value
  /// of any element changes.
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

  /// Executes [builder] within the [Zone] of the nearest [LScope].
  ///
  /// This bridges the gap between Widget-tree scoping ([InheritedWidget]) and
  /// static scoping ([Zone]), allowing [Levit.find] to work correctly.
  static R runBridged<R>(BuildContext context, R Function() builder) {
    final scope = _ScopeProvider.of(context);
    // Bridge widget-tree scope into Zone scope for `Levit.find` consistency.
    if (scope != null && scope != Ls.currentScope) {
      return scope.run(builder);
    }
    return builder();
  }

  /// Captures the nearest [LevitScope] from [context] and re-provides it to
  /// another subtree.
  ///
  /// This is useful for dialogs, overlays, and other route subtrees that are
  /// no longer descendants of the original [LScope] widget tree.
  ///
  /// If no local scope is found, [child] is returned unchanged.
  static Widget capture(BuildContext context, {required Widget child}) {
    final scope = _ScopeProvider.of(context);
    if (scope == null) return child;
    return _CapturedScope(scope: scope, child: child);
  }

  @override
  State<LScope> createState() => _LScopeState();

  /// The nearest [LevitScope] from the widget tree.
  static LevitScope? of(BuildContext context, {bool listen = false}) =>
      _ScopeProvider.of(context, listen: listen);
}

class _LScopeState extends State<LScope> {
  late final LevitScopeLifecycleController _lifecycle;
  LevitScope? _parent;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = widget.lifecycle ?? LevitScopeLifecycleController();
    _lifecycle.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
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
    final error = _lifecycle.error;
    if (error != null) {
      return widget.error?.call(context, error) ??
          Text('Scope error: $error', textDirection: TextDirection.ltr);
    }
    final scope = _lifecycle.scope;
    if (scope != null) return _ScopeProvider(scope: scope, child: widget.child);
    return widget.loading?.call(context) ?? const SizedBox.shrink();
  }
}
