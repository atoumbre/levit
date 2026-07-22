part of '../levit_flutter_core.dart';

/// A widget that creates a [LevitScope] tied to the widget tree.
///
/// Use [LScope] to provide dependencies for a specific subtree.
/// The scope is automatically closed when the widget is unmounted.
///
/// // Example usage:
/// ```dart
/// LScope(
///   dependencyFactory: (scope) => scope.put<MyController>(() => MyController()),
///   child: const MyPage(),
/// )
/// ```
class LScope extends StatefulWidget {
  /// An optional factory to register dependencies in this scope.
  final LScopeDependencyFactory? dependencyFactory;

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
      dependencyFactory: (s) {
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
      dependencyFactory: (s) {
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
      dependencyFactory: (s) {
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
  static Widget capture(
    BuildContext context, {
    required Widget child,
  }) {
    final scope = _ScopeProvider.of(context);
    if (scope == null) return child;
    return _CapturedScope(
      scope: scope,
      child: child,
    );
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

    final scopeName = widget.name ?? _uniqueScopeName(widget, this);
    final resolvedParent = parentScope ?? _ScopeProvider.of(context);
    _parentScope = resolvedParent;

    // Scope hierarchy must mirror widget hierarchy for deterministic resolution.
    _scope = resolvedParent != null
        ? resolvedParent.createScope(scopeName)
        : Levit.createScope(scopeName);

    try {
      widget.dependencyFactory?.call(_scope);
      _initialized = true;
    } catch (_) {
      _scope.dispose();
      rethrow;
    }
  }

  void _resetScope() {
    _scope.dispose();
    _initialized = false;
  }

  @override
  void didUpdateWidget(LScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldReset = false;

    if (widget.name != oldWidget.name) {
      shouldReset = true;
    }

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
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncParentScope(listen: false);
    return _ScopeProvider(
      scope: _scope,
      child: widget.child,
    );
  }
}
