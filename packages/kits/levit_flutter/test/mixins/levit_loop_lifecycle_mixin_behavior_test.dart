import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class LifecycleLoopController extends LevitController
    with LevitLoopExecutionMixin, LevitLoopExecutionLifecycleMixin {}

void main() {
  testWidgets('LevitLoopLifecycleMixin state transitions', (tester) async {
    final controller = LifecycleLoopController();
    controller.onInit();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(controller.pauseLifecycleServicesForce, isFalse);
    controller.onClose();
  });
}
