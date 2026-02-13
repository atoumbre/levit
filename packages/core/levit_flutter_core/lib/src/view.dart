part of '../levit_flutter_core.dart';

/// A widget that consumes a [LevitController] and builds UI.
///
/// [LView] combines finding a controller and building a reactive widget key.
/// By default, the build method acts as an [LWatch], triggering rebuilds on reactive changes.
///
/// Usage:
/// 1.  **Subclass:**
///     ```dart
///     class HomePage extends LView<HomeController> {
///       @override
///       Widget buildView(BuildContext context, HomeController controller) {
///         return Text(controller.title());
///       }
///     }
///     ```
/// 2.  **Builder:**
///     ```dart
///     LView<HomeController>(
///       builder: (context, controller) => Text(controller.title()),
///     );
///     ```
class LView<T> extends StatefulWidget {
  /// Resolves the dependency from the context.
  final T Function(BuildContext context)? resolver;

  /// Builds the widget tree using the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// Whether to wrap the view in an [LWatch].
  final bool autoWatch;

  /// Optional dependency keys for re-resolution.
  final List<Object?>? args;

  /// Creates a view with a dependency factory and a builder.
  const LView({
    super.key,
    this.resolver,
    this.builder,
    this.autoWatch = true,
    this.args,
  });

  /// Syntax sugar for consuming a [LevitStore].
  factory LView.store(
    LevitStore<T> state, {
    Key? key,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    List<Object?>? args,
  }) {
    return LView<T>(
      key: key,
      resolver: (context) => context.levit.find<T>(key: state),
      builder: builder,
      autoWatch: autoWatch,
      args: args,
    );
  }

  /// Registers and consumes a dependency of type [T].
  factory LView.put(
    T Function() create, {
    Key? key,
    String? tag,
    bool permanent = false,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    List<Object?>? args,
  }) {
    return LView<T>(
      key: key,
      resolver: (context) =>
          context.levit.put<T>(create, tag: tag, permanent: permanent),
      builder: builder,
      autoWatch: autoWatch,
      args: args,
    );
  }

  /// Builds the view content for the given [controller].
  ///
  /// Subclasses can override this instead of providing a [builder].
  @protected
  Widget buildView(
    BuildContext context,
    T controller,
  ) {
    final b = builder;
    if (b != null) {
      return b(context, controller);
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
  LevitScope? _boundScope;

  @override
  void initState() {
    super.initState();
    // Resolver is memoized per widget lifecycle to avoid rebuild-driven side effects.
    controller = _resolveController();
    _boundScope = LScope.of(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = LScope.of(context, listen: true);
    if (!identical(_boundScope, nextScope)) {
      _boundScope = nextScope;
      controller = _resolveController();
    }
  }

  @override
  void didUpdateWidget(LView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldUpdate = (widget.args != null || oldWidget.args != null)
        ? !_argsMatch(widget.args, oldWidget.args)
        : false;

    if (shouldUpdate) {
      controller = _resolveController();
    }
  }

  T _resolveController() {
    return widget.resolver?.call(context) ?? context.levit.find<T>();
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
  Widget build(BuildContext context) {
    // Single dispatch path supports both builder callback and subclass override.
    if (widget.autoWatch) {
      return LWatch(() => widget.buildView(context, controller));
    }

    return LScope.runBridged(
        context, () => widget.buildView(context, controller));
  }
}

/// A specialized view for asynchronous dependencies.
///
/// [LAsyncView] resolves a [Future] dependency and renders [loading], [error],
/// or [builder] (success) states. The resolution logic is memoized to prevent
/// infinite re-fetching.
///
/// Use [args] to forcefully re-trigger the resolution when arguments change.
class LAsyncView<T> extends StatefulWidget {
  /// Resolves the dependency asynchronously from the context.
  final Future<T> Function(BuildContext context)? resolver;

  /// Builds the widget tree using the resolved [controller].
  final Widget Function(BuildContext context, T controller)? builder;

  /// Whether to wrap the view in an [LWatch].
  final bool autoWatch;

  /// Builder for the loading state.
  final Widget Function(BuildContext context)? loading;

  /// Builder for the error state.
  final Widget Function(BuildContext context, Object error)? error;

  /// Optional dependency keys for re-resolution.
  final List<Object?>? args;

  /// Creates an async view.
  const LAsyncView({
    super.key,
    this.resolver,
    this.builder,
    this.autoWatch = true,
    this.loading,
    this.error,
    this.args,
  });

  /// Syntax sugar for consuming a [LevitAsyncStore].
  factory LAsyncView.store(
    LevitAsyncStore<T> store, {
    Key? key,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
    List<Object?>? args,
  }) =>
      LAsyncView<T>(
        key: key,
        resolver: (context) => context.levit.findAsync<T>(key: store),
        builder: builder,
        autoWatch: autoWatch,
        loading: loading,
        error: error,
        args: args,
      );

  /// Registers an async dependency of type [T] and consumes it.
  factory LAsyncView.put(
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
  }) {
    return LAsyncView<T>(
      key: key,
      resolver: (context) async {
        context.levit.lazyPutAsync<T>(create,
            tag: tag, permanent: permanent, isFactory: isFactory);
        return context.levit.findAsync<T>(tag: tag);
      },
      builder: builder,
      autoWatch: autoWatch,
      loading: loading,
      error: error,
      args: args,
    );
  }

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
  LevitScope? _boundScope;

  @override
  void initState() {
    super.initState();
    // Future is memoized per lifecycle to avoid repeated asynchronous resolution.
    future = _resolveFuture();
    _boundScope = LScope.of(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = LScope.of(context, listen: true);
    if (!identical(_boundScope, nextScope)) {
      _boundScope = nextScope;
      future = _resolveFuture();
    }
  }

  @override
  void didUpdateWidget(LAsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool shouldUpdate = false;
    if (widget.args != null || oldWidget.args != null) {
      // Explicit args override resolver identity checks.
      shouldUpdate = !_argsMatch(widget.args, oldWidget.args);
    } else {
      // Resolver identity is used when explicit args are not provided.
      shouldUpdate = widget.resolver != oldWidget.resolver;
    }

    if (shouldUpdate) {
      if (kDebugMode) {
        if (widget.resolver.runtimeType.toString().contains('Closure') ||
            widget.resolver.runtimeType.toString().contains('=>')) {
          debugPrint(
              'WARNING: [LAsyncView] resolver is an anonymous closure. This causes re-fetching on every build.\n'
              'Consider using a method reference or explicitly passing `args` to control updates.');
        }
      }
      setState(() {
        future = _resolveFuture();
      });
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

          return LScope.runBridged(
              context, () => widget.buildView(context, controller));
        }

        return widget.buildLoading(context);
      },
    );
  }
}
