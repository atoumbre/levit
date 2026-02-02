part of '../../levit_flutter.dart';

/// A widget that preserves its child when scrolled off-screen.
///
/// Wraps [AutomaticKeepAliveClientMixin] to prevent widgets from being disposed
/// in [ListView]s or [PageView]s.
///
/// Example:
/// ```dart
/// LKeepAlive(
///   child: MyExpensiveWidget(),
/// )
/// ```
class LKeepAlive extends StatefulWidget {
  /// The widget to keep alive.
  final Widget child;

  /// Whether the widget should currently be kept alive.
  ///
  /// Defaults to `true`. Changing this value at runtime updates the keep-alive state.
  final bool keepAlive;

  const LKeepAlive({
    super.key,
    required this.child,
    this.keepAlive = true,
  });

  @override
  State<LKeepAlive> createState() => _LKeepAliveState();
}

class _LKeepAliveState extends State<LKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(covariant LKeepAlive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
  }
}
