part of '../../levit_flutter.dart';

/// A wrapper widget that triggers callbacks when it enters or leaves the widget tree.
///
/// This is highly useful for index-based pagination or tracking impression analytics
/// in infinite lists without managing complex ScrollControllers.
class LWidgetMonitor extends StatefulWidget {
  /// The widget below this widget in the tree.
  final Widget child;

  /// Called immediately when this widget's state is initialized (i.e., when
  /// the item is built and added to the tree).
  final VoidCallback? onInit;

  /// Called when this widget is disposed (i.e., when the item is removed
  /// from the list, usually due to scrolling out of the cache extent).
  final VoidCallback? onDispose;

  const LWidgetMonitor({
    super.key,
    required this.child,
    this.onInit,
    this.onDispose,
  });

  @override
  State<LWidgetMonitor> createState() => _LWidgetMonitorState();
}

class _LWidgetMonitorState extends State<LWidgetMonitor> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
