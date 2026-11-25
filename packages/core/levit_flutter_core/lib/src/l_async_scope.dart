part of '../levit_flutter_core.dart';

/// An asynchronous version of [LScope].
///
/// Initializes the scope using an asynchronous [dependencyFactory] and
/// only renders [child] when initialization completes.
///
/// // Example usage:
/// ```dart
/// LAsyncScope(
///   dependencyFactory: (scope) async {
///     scope.lazyPutAsync(() => DataService.init());
///     await scope.findAsync<DataService>();
///   },
///   loading: (context) => const LoadingSpinner(),
///   child: const DataPage(),
/// )
/// ```
class LAsyncScope extends StatefulWidget {
  /// An async factory to register dependencies.
  /// The child will not render until this Future completes.
  final LAsyncScopeDependencyFactory dependencyFactory;

  /// The widget subtree to render after initialization.
  final Widget child;

  /// A descriptive name for the scope.
  ///
  /// When omitted, Levit generates a unique name from the widget runtime type
  /// and state identity. Set an explicit [name] only when you want a stable
  /// label for diagnostics.
  final String? name;

  /// Optional builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Optional builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  final List<Object?>? args;

  /// Optional completion/retry handle; must remain stable while mounted.
  final LevitScopeLifecycleController? lifecycle;

  const LAsyncScope({
    super.key,
    required this.dependencyFactory,
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
    final factory = widget.dependencyFactory;
    unawaited(
      _lifecycle.replace(
        parent: _parent!,
        name: widget.name ?? _uniqueScopeName(widget, this),
        initialize: (scope) => factory(scope),
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
