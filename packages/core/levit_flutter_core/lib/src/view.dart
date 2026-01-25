part of '../levit_flutter_core.dart';

class LView<T> extends StatefulWidget {
  /// Resolves the dependency from the context.
  final T Function(BuildContext context)? resolver;

  /// Builds the widget tree using the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// If `true`, wraps [builder] in an [LWatch]. Defaults to `true`.
  final bool autoWatch;

  /// Creates a view with a dependency factory and a builder.
  const LView({
    super.key,
    this.resolver,
    this.builder,
    this.autoWatch = true,
  });

  /// Syntax sugar for consuming a [LevitState].
  factory LView.state(
    LevitState<T> state, {
    Key? key,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
  }) =>
      LView<T>(
        key: key,
        resolver: (context) => context.levit.find<T>(key: state),
        builder: builder,
        autoWatch: autoWatch,
      );

  /// Builds the view content for the given [controller].
  ///
  /// Subclasses can override this instead of providing a [builder].
  @protected
  Widget buildView(BuildContext context, T controller) {
    if (builder != null) {
      return builder!(context, controller);
    }
    throw UnimplementedError(
      'LView: You must either provide a builder or override buildView in subclasses.',
    );
  }

  @override
  State<LView<T>> createState() => _LViewState<T>();
}

class _LViewState<T> extends State<LView<T>> {
  late T controller;

  @override
  void initState() {
    super.initState();
    // SAFETY: Resolver runs exactly ONCE.
    // This prevents accidental re-calculation during parent rebuilds.
    controller = _resolveController();
  }

  @override
  void didUpdateWidget(LView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller = _resolveController();
  }

  T _resolveController() {
    return widget.resolver?.call(context) ?? context.levit.find<T>();
  }

  @override
  Widget build(BuildContext context) {
    // We delegate back to the widget's buildView method
    // This supports both the 'builder' param and subclass overrides.
    if (widget.autoWatch) {
      return LWatch(() => widget.buildView(context, controller));
    }
    return widget.buildView(context, controller);
  }
}

/// A concrete widget for async controller resolution.
class LAsyncView<T> extends StatefulWidget {
  /// Resolves the dependency asynchronously from the context.
  final Future<T> Function(BuildContext context)? resolver;

  /// Builds the widget tree using the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// If `true`, wraps [builder] in an [LWatch]. Defaults to `true`.
  final bool autoWatch;

  /// Builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Creates an async view.
  const LAsyncView({
    super.key,
    this.resolver,
    this.builder,
    this.autoWatch = true,
    this.loading,
    this.error,
  });

  /// Syntax sugar for consuming a [LevitAsyncState].
  factory LAsyncView.state(
    LevitAsyncState<T> state, {
    Key? key,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
  }) =>
      LAsyncView<T>(
        key: key,
        resolver: (context) => context.levit.findAsync<T>(key: state),
        builder: builder,
        autoWatch: autoWatch,
        loading: loading,
        error: error,
      );

  /// Builds the view content for the given [controller].
  @protected
  Widget buildView(BuildContext context, T controller) {
    if (builder != null) {
      return builder!(context, controller);
    }
    throw UnimplementedError(
      'LView: You must either provide a builder or override buildView in subclasses.',
    );
  }

  @protected
  Widget buildLoading(BuildContext context) =>
      loading?.call(context) ?? const SizedBox.shrink();

  @protected
  Widget buildError(BuildContext context, Object err) =>
      error?.call(context, err) ?? Center(child: Text('Error: $err'));

  @override
  State<LAsyncView<T>> createState() => _LAsyncViewState<T>();
}

class _LAsyncViewState<T> extends State<LAsyncView<T>> {
  late Future<T> future;

  @override
  void initState() {
    super.initState();
    // SAFETY: Future created ONCE.
    // Prevents the "Infinite Loading Loop" problem.
    future = _resolveFuture();
  }

  @override
  void didUpdateWidget(LAsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the widget has changed, we might want to re-resolve.
    // However, LAsyncView is often used with LAsyncScopedView which replaces the whole scope.
    // To be safe, we re-resolve if the resolver factory changed.
    if (widget.resolver != oldWidget.resolver) {
      setState(() {
        future = _resolveFuture();
      });
    }
  }

  Future<T> _resolveFuture() {
    return widget.resolver?.call(context) ?? context.levit.findAsync<T>();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.buildError(context, snapshot.error!);
        }

        if (snapshot.hasData) {
          final controller = snapshot.data as T;
          if (widget.autoWatch) {
            return LWatch(() => widget.buildView(context, controller));
          }
          return widget.buildView(context, controller);
        }

        return widget.buildLoading(context);
      },
    );
  }
}

/// A convenience widget that combines [LScope] and [LView].
class LScopedView<T> extends StatelessWidget {
  /// Optional factory to register dependencies in the internal scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// Resolves the dependency for the view.
  final T Function(BuildContext context)? resolver;

  /// Builds the content of the view with the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// Whether to automatically watch reactive variables in [builder].
  final bool autoWatch;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// If provided, the internal scope will be recreated if the identity or value
  /// of any element in [args] changes.
  ///
  /// If [args] is `null` (default), the scope is **stable**: it will only be
  /// initialized once.
  final List<Object?>? args;

  const LScopedView({
    super.key,
    this.dependencyFactory,
    this.resolver,
    this.builder,
    this.autoWatch = true,
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
  }) =>
      LScopedView<T>(
        key: key,
        dependencyFactory: dependencyFactory,
        resolver: (context) => context.levit.find<T>(key: state),
        builder: builder,
        autoWatch: autoWatch,
        scopeName: scopeName,
        args: args,
      );

  /// Called when the internal scope is being configured.
  ///
  /// Subclasses can override this to register additional dependencies.
  @protected
  dynamic onConfigScope(LevitScope scope) {
    dependencyFactory?.call(scope);
  }

  /// Builds the view to be wrapped in the scope.
  ///
  /// Subclasses can override this to provide a custom view class.
  @protected
  Widget buildView(BuildContext context) {
    return LView<T>(
      autoWatch: autoWatch,
      resolver: resolver,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: scopeName,
      args: args,
      dependencyFactory: onConfigScope,
      child: buildView(context),
    );
  }
}

// A convenience widget that combines [LAsyncScope] and [LView].
///
/// This widget initializes an asynchronous dependency scope (showing a loading
/// indicator) and then renders an [LView] once the scope is ready.
class LAsyncScopedView<T> extends StatelessWidget {
  /// Async factory to register dependencies in the internal scope.
  /// The view will trigger [onLoading] until this future completes.
  final Future<dynamic> Function(LevitScope scope)? dependencyFactory;

  /// Resolves the dependency for the view.
  final T Function(BuildContext context)? resolver;

  /// Builds the content of the view with the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// Whether to automatically watch reactive variables in [builder].
  final bool autoWatch;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  /// Builder for the loading state (while scope is initializing).
  final Widget Function(BuildContext context)? loading;

  /// Builder for the error state (if scope initialization fails).
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for reactive re-initialization.
  ///
  /// If provided, the internal scope will be recreated if the identity or value
  /// of any element in [args] changes.
  final List<Object?>? args;

  const LAsyncScopedView({
    super.key,
    this.dependencyFactory,
    this.resolver,
    this.builder,
    this.autoWatch = true,
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
  }) =>
      LAsyncScopedView<T>(
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

  /// Called when the internal scope is being configured asynchronously.
  ///
  /// Subclasses can override this to register additional dependencies.
  @protected
  Future<void> onConfigScope(LevitScope scope) async {
    if (dependencyFactory != null) {
      await dependencyFactory!(scope);
    }
  }

  /// Builds the view to be wrapped in the scope.
  ///
  /// Subclasses can override this to provide a custom view class.
  @protected
  Widget buildView(BuildContext context) {
    return LView<T>(
      autoWatch: autoWatch,
      resolver: resolver,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LAsyncScope(
      name: scopeName,
      args: args,
      dependencyFactory: onConfigScope,
      loading: loading,
      error: error,
      child: buildView(context),
    );
  }
}
