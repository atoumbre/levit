import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class LifecycleController extends LevitController with LevitAppLifecycleMixin {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LifecycleLoopController extends LevitController
    with LevitLoopExecutionMixin, LevitLoopExecutionLifecycleMixin {
  @override
  void onInit() => super.onInit();
  @override
  void onClose() => super.onClose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('levit_flutter Final Gaps', () {
    testWidgets('LevitAppLifecycleMixin coverage', (tester) async {
      final controller = LifecycleController();
      controller.onInit();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);

      // Hit AppLifecycleState.hidden (60-61 in _AppLifecycleObserver)
      try {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      } catch (_) {}

      controller.onClose();
    });

    testWidgets('LKeepAlive coverage', (tester) async {
      bool keepAlive = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
            splashFactory: NoSplash.splashFactory,
          ),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  LKeepAlive(
                    keepAlive: keepAlive,
                    child: const Text('keep'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => keepAlive = !keepAlive),
                    child: const Text('toggle'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('keep'), findsOneWidget);

      // Trigger didUpdateWidget (37-41)
      await tester.tap(find.text('toggle'));
      await tester.pump();
    });

    testWidgets('LevitLoopLifecycleMixin coverage', (tester) async {
      final controller = LifecycleLoopController();
      controller.onInit();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(controller.pauseLifecycleServicesForce, isFalse);

      controller.onClose();
    });
  });
}
