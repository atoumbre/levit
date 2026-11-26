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
