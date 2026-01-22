import 'package:flutter/widgets.dart';
import 'package:levit_dart/levit_dart.dart';
import 'package:levit_flutter/src/watch.dart';
import 'package:levit_flutter/src/scope.dart';

/// A base [StatelessWidget] designed for clean architecture UI components.
///
/// [LView] automatically resolves a controller of type [T] from the dependency
/// injection system (nearest [LScope] or global [Levit]). It also provides
/// optional automatic reactive tracking via [autoWatch].
///
/// **WARNING:** Controllers created via [createController] are registered in the
/// *current scope*. If used in a long-lived scope (like root), they will NOT
/// be disposed automatically when this widget is removed from the tree.
/// Use [LScopedView] for transient controllers that should be automatically
/// disposed with the view.
///
/// Use this class as the base for your screens or complex widgets that map
/// 1:1 with a controller.
///
/// ```dart
/// class CounterPage extends LView<CounterController> {
///   const CounterPage({super.key});
///
///   @override
///   Widget buildContent(BuildContext context, CounterController controller) {
///     return Scaffold(
///       body: Center(child: Text('Count: ${controller.count.value}')),
///     );
///   }
/// }
/// ```
abstract class LView<T> extends StatelessWidget {
  const LView({super.key});

  /// Optional tag to use when finding the controller.
  String? get tag => null;

  /// Optional factory to create the controller if it's not found.
  ///
  /// If provided and the controller is not registered, this will be used to
  /// create and register it (lazy-put style). This is useful for self-contained
  /// views that don't rely on external routing setup.
  T? createController() => null;

  /// Whether the controller created via [createController] should be permanent.
  bool get permanent => false;

  /// Whether to wrap [buildContent] in [LWatch] for automatic rebuilding.
  /// Defaults to `true`.
  ///
  /// Set this to `false` if you want to manage granular rebuilding manually
  /// using [LWatch] or other widgets.
  bool get autoWatch => true;

  /// Override this method to build your widget tree.
  ///
  /// The [controller] is automatically injected.
  Widget buildContent(BuildContext context, T controller);

  @override
  Widget build(BuildContext context) {
    // Resolve controller using the optimized path (avoiding LevitProvider allocation)
    final T controller;
    final scope = LScope.of(context);
    if (scope != null) {
      final instance = scope.findOrNull<T>(tag: tag);
      if (instance != null) {
        controller = instance;
      } else {
        controller = scope.put<T>(() {
          final created = createController();
          if (created == null) {
            throw StateError(
                'LView: Controller $T not found and createController() returned null.');
          }
          return created;
        }, tag: tag, permanent: permanent);
      }
    } else {
      final instance = Levit.findOrNull<T>(tag: tag);
      if (instance != null) {
        controller = instance;
      } else {
        controller = Levit.put<T>(() {
          final created = createController();
          if (created == null) {
            throw StateError(
                'LView: Controller $T not found and createController() returned null.');
          }
          return created;
        }, tag: tag, permanent: permanent);
      }
    }

    if (autoWatch) {
      return LWatch(() => buildContent(context, controller));
    }
    return buildContent(context, controller);
  }
}

/// A base [StatefulWidget] that integrates with the Levit controller system.
///
/// Use [LStatefulView] when you need the full lifecycle of a [StatefulWidget]
/// (e.g., `initState`, `dispose`) in addition to accessing a controller.
/// This is less common in pure Levit architecture but useful for integrations.
abstract class LStatefulView<T> extends StatefulWidget {
  /// Creates a stateful view.
  const LStatefulView({super.key});

  /// Optional tag to use when finding the controller.
  String? get tag => null;

  /// Optional factory to create the controller if it's not found.
  T? createController() => null;

  /// Whether the controller created via [createController] should be permanent.
  bool get permanent => false;

  /// Whether to wrap `buildContent` in [LWatch] for automatic rebuilding.
  /// Defaults to `true`.
  bool get autoWatch => true;
}

/// The base [State] class for [LStatefulView].
///
/// Provides access to the [controller] and additional lifecycle hooks.
abstract class LState<W extends LStatefulView<T>, T> extends State<W> {
  /// Base constructor.
  LState();

  /// The controller instance resolved from the dependency injection system.
  T get controller {
    if (context.levit.isRegistered<T>(tag: widget.tag)) {
      return context.levit.find<T>(tag: widget.tag);
    }

    return context.levit.put<T>(() {
      final created = widget.createController();
      if (created == null) {
        throw StateError(
            'LStatefulView: Controller $T not found and createController() returned null.');
      }
      return created;
    }, tag: widget.tag, permanent: widget.permanent);
  }

  /// Called immediately after [initState].
  ///
  /// Use this for initialization logic that requires access to the context
  /// or the controller (which are safe to access here).
  void onInit() {}

  /// Called immediately before `dispose`.
  ///
  /// Use this for cleanup logic.
  void onClose() {}

  @override
  void initState() {
    super.initState();
    onInit();
  }

  @override
  void dispose() {
    onClose();
    super.dispose();
  }

  /// Override this method to build your widget tree.
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (widget.autoWatch) {
      return LWatch(() => buildContent(context));
    }
    return buildContent(context);
  }
}
