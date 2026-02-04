part of '../../levit_flutter.dart';

/// A widget that detects when it enters or leaves the widget tree.
///
/// Useful for triggering one-shot setup or teardown hooks tied to mount/unmount.
///
/// Note: This does not detect viewport visibility. It only reports insertion
/// and removal from the widget tree.
///
/// Example:
/// ```dart
/// LWidgetMonitor(
///   onInit: () => controller.loadNextPage(),
///   child: LoadingSpinner(),
/// )
/// ```
class LWidgetMonitor extends StatefulWidget {
  /// The widget to monitor.
  final Widget child;

  /// Called when the widget is initialized (mounted).
  final VoidCallback? onInit;

  /// Called when the widget is disposed (unmounted).
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
