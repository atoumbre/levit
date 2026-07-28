import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestTasksController extends LevitController with LevitTasksMixin {}

class TestReactiveTasksController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  group('LevitTasksMixin tasksEngine access', () {
    test('lazy-inits engine before onInit for manual test construction',
        () async {
      final controller = TestTasksController();

      final result = await controller.tasksEngine.schedule((_) async => 'ok');

      expect(result, 'ok');
      await controller.onClose();
    });

    test('onInit reconfigures an engine created before initialization',
        () async {
      final controller = TestTasksController()..tasksEngine;
      controller.didAttachToScope(LevitScope.root('test'), key: 'test');
      controller.onInit();
      await controller.onClose();
    });

    test('throws a clear error after the controller is closed', () async {
      final controller = TestTasksController();
      controller.onInit();
      await controller.onClose();

      expect(
        () => controller.tasksEngine,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'tasksEngine accessed after the controller was closed.',
          ),
        ),
      );
    });
  });

  group('LevitReactiveTasksMixin tasksEngine access', () {
    test('lazy-inits engine before onInit for manual test construction',
        () async {
      final controller = TestReactiveTasksController();

      final result = await controller.tasksEngine.schedule((_) async => 42);

      expect(result, 42);
      await controller.onClose();
    });

    test('lazy-inits isBusy and totalProgress before onInit', () async {
      final controller = TestReactiveTasksController();

      expect(controller.isBusy.value, isFalse);
      expect(controller.totalProgress.value, 0.0);

      await controller.onClose();
    });

    test('throws a clear error after the controller is closed', () async {
      final controller = TestReactiveTasksController();
      controller.onInit();
      await controller.onClose();

      expect(
        () => controller.isBusy,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Reactive task state accessed after the controller was closed.',
          ),
        ),
      );
    });
  });
}
