import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

/// Shows a [Dialog] via [showDialog] that keeps access to the nearest Levit
/// scope from [context].
///
/// Wraps the dialog content with [LScope.capture] so `context.levit.find` still
/// resolves page- or app-local dependencies inside the overlay route. All
/// optional parameters are forwarded directly to Flutter's [showDialog].
///
/// Note: [LScope.capture] borrows the nearest scope without extending its
/// lifetime. If the originating route or scope widget unmounts while a
/// root-navigator dialog remains open, the captured scope still disposes.
///
/// ```dart
/// final confirmed = await showLevitDialog<bool>(
///   context: context,
///   builder: (dialogContext) {
///     final controller = dialogContext.levit.find<EditorController>();
///     return AlertDialog(
///       title: Text('Discard ${controller.draftName()}?'),
///       actions: [
///         TextButton(
///           onPressed: () => Navigator.of(dialogContext).pop(true),
///           child: const Text('Discard'),
///         ),
///       ],
///     );
///   },
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
Future<T?> showLevitDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
}) {
  final captured = LScope.capture(context, child: Builder(builder: builder));
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    builder: (_) => captured,
  );
}

/// Shows a modal bottom sheet via [showModalBottomSheet] that keeps access to
/// the nearest Levit scope from [context].
///
/// Wraps the sheet content with [LScope.capture] so `context.levit.find` still
/// resolves page- or app-local dependencies inside the overlay route. All
/// optional parameters are forwarded directly to Flutter's
/// [showModalBottomSheet].
///
/// Note: [LScope.capture] borrows the nearest scope without extending its
/// lifetime. If the originating route or scope widget unmounts while the sheet
/// remains open, the captured scope still disposes.
///
/// ```dart
/// await showLevitModalBottomSheet<void>(
///   context: context,
///   builder: (sheetContext) {
///     final filter = sheetContext.levit.find<FilterController>();
///     return FilterSheet(controller: filter);
///   },
/// );
/// ```
///
/// {@category Flutter Widgets & Interop}
Future<T?> showLevitModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
}) {
  final captured = LScope.capture(context, child: Builder(builder: builder));
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    barrierLabel: barrierLabel,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    builder: (_) => captured,
  );
}
