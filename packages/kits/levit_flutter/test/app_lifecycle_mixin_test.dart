import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class TestLifecycleController extends LevitController
    with LevitAppLifecycleMixin {
  int resumedCount = 0;
  int pausedCount = 0;
  int inactiveCount = 0;
  int detachedCount = 0;
  int hiddenCount = 0;

  @override
  void onAppResumed() => resumedCount++;

  @override
  void onAppPaused() => pausedCount++;

  @override
  void onAppInactive() => inactiveCount++;

  @override
  void onAppDetached() => detachedCount++;

  @override
  void onAppHidden() => hiddenCount++;
}

void main() {
  group('LevitAppLifecycleMixin', () {
    testWidgets('calls lifecycle methods correctly', (tester) async {
      final controller = TestLifecycleController();
      controller.onInit();

      // Simulate lifecycle changes via channel or binding
      // We can't access the private _observer directly, but we can rely on Global WidgetsBinding
      // However, forcing the binding to change state is easier:

      // Resumed
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.resumedCount, 1);

      // Paused
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(controller.pausedCount, 1);

      // Inactive
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(controller.inactiveCount, 1);

      // Detached
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(controller.detachedCount, 1);

      // Hidden
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(controller.hiddenCount, 1);

      controller.onClose();
    });
  });
}
