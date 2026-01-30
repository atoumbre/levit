part of '../levit_flutter_core.dart';

/// A convenience widget that combines [LScope] and [LView].
///
/// [LScopedView] creates an isolated dependency scope for a specific part of
/// the widget tree and immediately resolves a controller to build its content.
class LScopedView<T> extends LView<T> {
  /// Optional factory to register dependencies in the internal scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  /// Optional dependency keys for reactive re-initialization.
  final List<Object?>? args;

  const LScopedView({
    super.key,
    this.dependencyFactory,
    super.resolver,
    super.builder,
    super.autoWatch = true,
    this.scopeName,
    this.args,
  });

  /// Syntax sugar for consuming a [LevitState] within a new scope.
  factory LScopedView.state(
    LevitState<T> state, {
    Key? key,
    dynamic Function(LevitScope scope)? dependencyFactory,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    String? scopeName,
    List<Object?>? args,
  }) {
    return LScopedView<T>(
      key: key,
      dependencyFactory: dependencyFactory,
      resolver: (context) => context.levit.find<T>(key: state),
      builder: builder,
      autoWatch: autoWatch,
      scopeName: scopeName,
      args: args,
    );
  }

  /// Shorthand for creating a scope, immediately registering a dependency, and consuming it.
  factory LScopedView.put(
    T Function() create, {
    Key? key,
    String? tag,
    bool permanent = false,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    String? scopeName,
    List<Object?>? args,
  }) {
    return LScopedView<T>(
      key: key,
      scopeName: scopeName,
      args: args,
      dependencyFactory: (s) =>
          s.put<T>(create, tag: tag, permanent: permanent),
      resolver: (context) => context.levit.find<T>(tag: tag),
      builder: builder,
      autoWatch: autoWatch,
    );
  }

  /// Called when the internal scope is being configured.
  ///
  /// Subclasses can override this to register dependencies.
  @protected
  dynamic onConfigScope(LevitScope scope) {
    return dependencyFactory?.call(scope);
  }

  @override
  State<LScopedView<T>> createState() => _LScopedViewState<T>();
}

class _LScopedViewState<T> extends State<LScopedView<T>> {
  @override
  Widget build(BuildContext context) {
    return LScope(
      name: widget.scopeName,
      args: widget.args,
      dependencyFactory: widget.onConfigScope,
      child: Builder(
        builder: (context) {
          final controller =
              widget.resolver?.call(context) ?? context.levit.find<T>();
          if (widget.autoWatch) {
            return LWatch(() => widget.buildView(context, controller));
          }
          return widget.buildView(context, controller);
        },
      ),
    );
  }
}

/// A convenience widget that combines [LAsyncScope] and [LView].
///
/// [LAsyncScopedView] initializes an asynchronous dependency scope and then
/// renders an [LView] once the scope is ready.
class LAsyncScopedView<T> extends LView<T> {
  /// Async factory to register dependencies in the internal scope.
  final Future<dynamic> Function(LevitScope scope)? dependencyFactory;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  /// Builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  final List<Object?>? args;

  const LAsyncScopedView({
    super.key,
    this.dependencyFactory,
    super.resolver,
    super.builder,
    super.autoWatch = true,
    this.scopeName,
    this.loading,
    this.error,
    this.args,
  });

  /// Syntax sugar for consuming a [LevitState] within a new async scope.
  factory LAsyncScopedView.state(
    LevitState<T> state, {
    Key? key,
    Future Function(LevitScope scope)? dependencyFactory,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    String? scopeName,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
    List<Object?>? args,
  }) {
    return LAsyncScopedView<T>(
      key: key,
      dependencyFactory: dependencyFactory,
      resolver: (context) => context.levit.find<T>(key: state),
      builder: builder,
      autoWatch: autoWatch,
      scopeName: scopeName,
      loading: loading,
      error: error,
      args: args,
    );
  }

  /// Called when the internal scope is being configured asynchronously.
  ///
  /// Subclasses can override this to register additional dependencies.
  @protected
  Future<void> onConfigScope(LevitScope scope) async {
    if (dependencyFactory != null) {
      await dependencyFactory!(scope);
    }
  }

  @override
  State<LAsyncScopedView<T>> createState() => _LAsyncScopedViewState<T>();
}

class _LAsyncScopedViewState<T> extends State<LAsyncScopedView<T>> {
  @override
  Widget build(BuildContext context) {
    return LAsyncScope(
      name: widget.scopeName,
      args: widget.args,
      dependencyFactory: widget.onConfigScope,
      loading: widget.loading,
      error: widget.error,
      child: Builder(
        builder: (context) {
          final controller =
              widget.resolver?.call(context) ?? context.levit.find<T>();
          if (widget.autoWatch) {
            return LWatch(() => widget.buildView(context, controller));
          }
          return widget.buildView(context, controller);
        },
      ),
    );
  }
}

/// A convenience widget that combines [LScope] and [LAsyncView].
///
/// [LScopedAsyncView] creates an isolated dependency scope immediately,
/// but resolves its controller asynchronously.
class LScopedAsyncView<T> extends LAsyncView<T> {
  /// Optional factory to register dependencies in the internal scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  const LScopedAsyncView({
    super.key,
    this.dependencyFactory,
    super.resolver,
    super.builder,
    super.autoWatch = true,
    super.loading,
    super.error,
    super.args,
    this.scopeName,
  });

  /// Syntax sugar for consuming a [LevitAsyncState] within a new scope.
  factory LScopedAsyncView.state(
    LevitAsyncState<T> state, {
    Key? key,
    dynamic Function(LevitScope scope)? dependencyFactory,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
    List<Object?>? args,
    String? scopeName,
  }) {
    return LScopedAsyncView<T>(
      key: key,
      dependencyFactory: dependencyFactory,
      resolver: (context) => context.levit.findAsync<T>(key: state),
      builder: builder,
      autoWatch: autoWatch,
      loading: loading,
      error: error,
      args: args,
      scopeName: scopeName,
    );
  }

  /// Shorthand for creating a scope, registering an async dependency, and consuming it.
  factory LScopedAsyncView.put(
    Future<T> Function() create, {
    Key? key,
    String? tag,
    bool permanent = false,
    bool isFactory = false,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
    List<Object?>? args,
    String? scopeName,
  }) {
    return LScopedAsyncView<T>(
      key: key,
      scopeName: scopeName,
      args: args,
      dependencyFactory: (s) => s.lazyPutAsync<T>(create,
          tag: tag, permanent: permanent, isFactory: isFactory),
      resolver: (context) => context.levit.findAsync<T>(tag: tag),
      builder: builder,
      autoWatch: autoWatch,
      loading: loading,
      error: error,
    );
  }

  /// Called when the internal scope is being configured.
  @protected
  dynamic onConfigScope(LevitScope scope) {
    return dependencyFactory?.call(scope);
  }

  @override
  State<LScopedAsyncView<T>> createState() => _LScopedAsyncViewState<T>();
}

class _LScopedAsyncViewState<T> extends State<LScopedAsyncView<T>> {
  @override
  Widget build(BuildContext context) {
    return LScope(
      name: widget.scopeName,
      args: widget.args,
      dependencyFactory: widget.onConfigScope,
      child: Builder(
        builder: (context) {
          return LAsyncView<T>(
            resolver: widget.resolver,
            builder: widget.builder,
            autoWatch: widget.autoWatch,
            loading: widget.loading,
            error: widget.error,
            args: widget.args,
          );
        },
      ),
    );
  }
}
