import 'package:flutter/widgets.dart';

/// A widget that keeps its child alive even when it is scrolled out of view or
/// moved off-screen in a [PageView] or [TabBarView].
///
/// This is a wrapper around [AutomaticKeepAliveClientMixin].
class LKeepAlive extends StatefulWidget {
  final Widget child;

  /// Whether to keep the child alive. Defaults to true.
  ///
  /// If changed dynamically, it will trigger an update to the keep-alive state.
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
