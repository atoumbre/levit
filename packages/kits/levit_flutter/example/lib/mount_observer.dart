import 'package:flutter/widgets.dart';

/// A widget that detects when it enters or leaves the widget tree.
///
/// Useful for triggering one-shot setup or teardown hooks tied to mount/unmount.
///
/// Note: This does not detect viewport visibility. It only reports insertion
/// and removal from the widget tree.
///
/// // Example usage:
/// ```dart
/// MountObserver(
///   onInit: () => controller.loadNextPage(),
///   child: LoadingSpinner(),
/// )
/// ```
class MountObserver extends StatefulWidget {
  /// The widget to monitor.
  final Widget child;

  /// Called when the widget is initialized (mounted).
  final VoidCallback? onInit;

  /// Called when the widget is disposed (unmounted).
  final VoidCallback? onDispose;

  const MountObserver({
    super.key,
    required this.child,
    this.onInit,
    this.onDispose,
  });

  @override
  State<MountObserver> createState() => _MountObserverState();
}

class _MountObserverState extends State<MountObserver> {
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
