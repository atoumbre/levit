import 'package:flutter/material.dart'; import 'package:flutter_test/flutter_test.dart'; import 'package:levit_flutter/levit_flutter.dart';
class LifecycleController extends LevitController with LevitAppLifecycleMixin {}
void main() {
  testWidgets('LevitAppLifecycleMixin observer state changes', (tester) async {
    final controller = LifecycleController(); controller.onInit();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    try { tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden); } catch (_) {}
    controller.onClose();
  });
}