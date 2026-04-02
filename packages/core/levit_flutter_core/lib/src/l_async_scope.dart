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

  // Guard against re-initializing async scope during normal rebuilds.
  bool _initialized = false;
  LevitScope? _parentScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncParentScope(listen: true);
  }

  void _syncParentScope({required bool listen}) {
    final newParent = _ScopeProvider.of(context, listen: listen);
    if (_initialized && !identical(_parentScope, newParent)) {
      _resetScope();
    }
    _initScope(parentScope: newParent);
  }

  void _initScope({LevitScope? parentScope}) {
    if (_initialized) return;

    final scopeName = widget.name ?? 'LAsyncScope';

    // Parent scope is resolved from inherited context, not global scope.
    final resolvedParent = parentScope ?? _ScopeProvider.of(context);
    _parentScope = resolvedParent;

    // Scope hierarchy must mirror widget hierarchy for deterministic resolution.
    _scope = resolvedParent != null
        ? resolvedParent.createScope(scopeName)
        : Levit.createScope(scopeName);

    // Initialization future is created once per scope lifecycle.
    _initFuture =
        Future.sync(() => widget.dependencyFactory(_scope)).catchError((e) {
      _scope.dispose();
      throw e;
    });
    _initialized = true;
  }

  void _resetScope() {
    _scope.dispose();
    _initialized = false;
  }

  @override
  void didUpdateWidget(LAsyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

    if (widget.name != oldWidget.name) {
      shouldReset = true;
    }

    // Explicit args control when async dependencies are recreated.
    if (widget.args != null || oldWidget.args != null) {
      if (!_scopeArgsMatch(widget.args, oldWidget.args)) {
        shouldReset = true;
      }
    }

    if (shouldReset) {
      _resetScope();
      _initScope();
    }
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
    _syncParentScope(listen: false);
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Error state keeps the failed scope isolated from the subtree.
        if (snapshot.hasError) {
          return widget.error?.call(context, snapshot.error!) ??
              Center(
                child: Text(
                  'Scope Initialization Error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
        }

        // Publish scope only after dependency initialization completes.
        if (snapshot.connectionState == ConnectionState.done) {
          return _ScopeProvider(
            scope: _scope,
            child: widget.child,
          );
        }

        // Loading state avoids exposing a partially initialized scope.
        return widget.loading?.call(context) ?? const SizedBox.shrink();
      },
    );
  }
}
