part of '../levit_flutter_core.dart';

/// A widget that manages its own dependency scope and builds a view.
///
/// [LScopedView] creates a new [LevitScope] for its subtree, registers dependencies
/// via [dependencyFactory], and then builds the UI using [LView].
/// When the widget is unmounted, the scope and all its dependencies are disposed.
///
/// Example:
/// ```dart
/// LScopedView<ProfileController>.put(
///   () => ProfileController(),
///   builder: (context, controller) => ProfilePage(controller),
/// );
/// ```
class LScopedView<T> extends LView<T> {
  /// Optional factory to register dependencies in the internal scope.
  final dynamic Function(LevitScope scope)? dependencyFactory;

  /// A descriptive name for the internal scope.
  final String? scopeName;

  const LScopedView({
    super.key,
    this.dependencyFactory,
    super.resolver,
    super.builder,
    super.orElse,
    super.autoWatch = true,
    this.scopeName,
    super.args,
  });

  /// Syntax sugar for consuming a [LevitStore] within a new scope.
  factory LScopedView.store(
    LevitStore<T> state, {
    Key? key,
    dynamic Function(LevitScope scope)? dependencyFactory,
    required Widget Function(BuildContext context, T controller) builder,
    Widget Function(BuildContext context)? orElse,
    bool autoWatch = true,
    String? scopeName,
    List<Object?>? args,
  }) {
    return LScopedView<T>(
      key: key,
      dependencyFactory: dependencyFactory,
      resolver: (context) => context.levit.findOrNull<T>(key: state),
      builder: builder,
      orElse: orElse,
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
    Widget Function(BuildContext context)? orElse,
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
      resolver: (context) => context.levit.findOrNull<T>(tag: tag),
      builder: builder,
      orElse: orElse,
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
              widget.resolver?.call(context) ?? context.levit.findOrNull<T>();
          if (controller == null) {
            final fallback = widget.orElse;
            if (fallback != null) return fallback(context);
            throw StateError(
              'LScopedView<$T>: controller not found and no orElse provided.',
            );
          }
          if (widget.autoWatch) {
            return LWatch(() => widget.buildView(context, controller));
          }
          return LScope.runBridged(
              context, () => widget.buildView(context, controller));
        },
      ),
    );
  }
}

/// A widget that creates a synchronous scope but resolves its controller asynchronously.
///
/// [LScopedAsyncView] initializes the scope immediately with [LScope], then
/// uses [LAsyncView] to wait for async controller resolution.
///
/// In short:
/// - **Sync scope setup**
/// - **Async controller resolution**
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

  /// Syntax sugar for consuming a [LevitAsyncStore] within a new scope.
  factory LScopedAsyncView.store(
    LevitAsyncStore<T> store, {
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
      resolver: (context) => context.levit.findAsync<T>(key: store),
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
