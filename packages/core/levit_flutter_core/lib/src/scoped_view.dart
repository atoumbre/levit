part of '../levit_flutter_core.dart';

/// A widget that manages its own dependency scope and builds a view.
///
/// [LScopedView] creates a new [LScope] for its subtree, registers dependencies
/// via [configure] / [onConfigureScope], resolves [T] inside that scope, and
/// renders [buildView] / [builder] (wrapped in [LWatch] when [autoWatch] is
/// `true`). When the widget is unmounted, the scope and all its dependencies
/// are disposed. Changing [args] recreates the internal [LScope] and re-runs
/// [onConfigureScope].
///
/// Subclassing with [onConfigureScope] is a first-class pattern alongside
/// [LScopedView.put]. With [autoWatch] `true` (default), read reactives directly
/// in [buildView]; do not wrap the entire return in [LWatch].
///
/// ```dart
/// LScopedView<ProfileController>.put(
///   () => ProfileController(),
///   builder: (context, controller) => ProfilePage(controller),
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
class LScopedView<T> extends LView<T> {
  /// Optional callback to register dependencies in the internal scope.
  final void Function(LevitScope scope)? configure;

  /// A descriptive name for the internal scope.
  ///
  /// When omitted, Levit generates a unique name from this widget's runtime
  /// type (so subclasses like `HomePage` appear in diagnostics) and state
  /// identity. Set [scopeName] only when you want a stable label.
  final String? scopeName;

  /// Creates a scoped view that owns a child [LScope] and resolves [T].
  const LScopedView({
    super.key,
    this.configure,
    super.resolver,
    super.builder,
    super.orElse,
    super.autoWatch = true,
    this.scopeName,
    super.args,
  });

  /// Creates a child scope and consumes [LevitStore] [state].
  ///
  /// Note: [localOnly] defaults to `false`, so this inherits an ancestor
  /// instance of [state] unless `localOnly: true` is passed to create/reuse an
  /// instance exclusively inside this widget's new child scope.
  factory LScopedView.store(
    LevitStore<T> state, {
    Key? key,
    bool localOnly = false,
    void Function(LevitScope scope)? configure,
    required Widget Function(BuildContext context, T controller) builder,
    Widget Function(BuildContext context)? orElse,
    bool autoWatch = true,
    String? scopeName,
    List<Object?>? args,
  }) {
    return LScopedView<T>(
      key: key,
      configure: configure,
      resolver: (context) => _resolveStore(context, state, localOnly),
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
      configure: (s) {
        s.put<T>(create, tag: tag, permanent: permanent);
      },
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
  void onConfigureScope(LevitScope scope) {
    configure?.call(scope);
  }

  @override
  State<LScopedView<T>> createState() => _LScopedViewState<T>();
}

class _LScopedViewState<T> extends State<LScopedView<T>> {
  @override
  Widget build(BuildContext context) {
    return LScope(
      name: widget.scopeName ?? _uniqueScopeName(widget, this),
      args: widget.args,
      configure: widget.onConfigureScope,
      child: Builder(
        builder: (context) {
          final resolver = widget.resolver;
          final controller = resolver != null
              ? resolver(context)
              : context.levit.findOrNull<T>();
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
            context,
            () => widget.buildView(context, controller),
          );
        },
      ),
    );
  }
}

/// A widget that creates a synchronous [LScope] and resolves [T] asynchronously
/// via [LAsyncView].
///
/// With [autoWatch] `true` (default), read reactives directly in
/// [buildView] / [builder] without wrapping the entire return in [LWatch].
/// Changing [args] recreates the internal [LScope] and re-runs async
/// resolution.
///
/// ```dart
/// LAsyncScopedView<CatalogController>.put(
///   () async => await CatalogController.load(),
///   loading: (_) => const CircularProgressIndicator(),
///   builder: (context, controller) => CatalogView(controller),
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
class LAsyncScopedView<T> extends LAsyncView<T> {
  /// Optional callback to register dependencies in the internal scope.
  final void Function(LevitScope scope)? configure;

  /// A descriptive name for the internal scope.
  ///
  /// When omitted, Levit generates a unique name from this widget's runtime
  /// type and state identity. Set [scopeName] only when you want a stable
  /// label for diagnostics.
  final String? scopeName;

  /// Creates an async scoped view that owns a child [LScope] and resolves [T]
  /// asynchronously.
  const LAsyncScopedView({
    super.key,
    this.configure,
    super.resolver,
    super.builder,
    super.autoWatch = true,
    super.loading,
    super.error,
    super.args,
    this.scopeName,
  });

  /// Creates a child scope and consumes [LevitAsyncStore] [store].
  ///
  /// Note: [localOnly] defaults to `false`, so this inherits an ancestor
  /// instance of [store] unless `localOnly: true` is passed to create/reuse an
  /// instance exclusively inside this widget's new child scope.
  factory LAsyncScopedView.store(
    LevitAsyncStore<T> store, {
    Key? key,
    bool localOnly = false,
    void Function(LevitScope scope)? configure,
    required Widget Function(BuildContext context, T controller) builder,
    bool autoWatch = true,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error)? error,
    List<Object?>? args,
    String? scopeName,
  }) {
    return LAsyncScopedView<T>(
      key: key,
      configure: configure,
      resolver: (context) => _resolveAsyncStore(context, store, localOnly),
      builder: builder,
      autoWatch: autoWatch,
      loading: loading,
      error: error,
      args: args,
      scopeName: scopeName,
    );
  }

  /// Shorthand for creating a scope, registering an async dependency, and consuming it.
  factory LAsyncScopedView.put(
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
    return LAsyncScopedView<T>(
      key: key,
      scopeName: scopeName,
      args: args,
      configure: (s) {
        s.lazyPutAsync<T>(
          create,
          tag: tag,
          permanent: permanent,
          isFactory: isFactory,
        );
      },
      resolver: (context) => context.levit.findAsync<T>(tag: tag),
      builder: builder,
      autoWatch: autoWatch,
      loading: loading,
      error: error,
    );
  }

  /// Called when the internal scope is being configured.
  @protected
  void onConfigureScope(LevitScope scope) {
    configure?.call(scope);
  }

  @override
  State<LAsyncScopedView<T>> createState() => _LAsyncScopedViewState<T>();
}

class _LAsyncScopedViewState<T> extends State<LAsyncScopedView<T>> {
  @override
  Widget build(BuildContext context) {
    return LScope(
      name: widget.scopeName ?? _uniqueScopeName(widget, this),
      args: widget.args,
      configure: widget.onConfigureScope,
      child: Builder(
        builder: (context) {
          return LAsyncView<T>(
            resolver: widget.resolver,
            builder: widget.buildView,
            autoWatch: widget.autoWatch,
            loading: widget.buildLoading,
            error: widget.buildError,
            args: widget.args,
          );
        },
      ),
    );
  }
}
