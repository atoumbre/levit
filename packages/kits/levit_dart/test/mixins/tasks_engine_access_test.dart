import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestTasksController extends LevitController with LevitTasksMixin {}

class TestReactiveTasksController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LevitTasksMixin tasksEngine access', () {
    test('lazy-inits engine before onInit for manual test construction',
        () async {
      final controller = TestTasksController();

      final result = await controller.tasksEngine.schedule(() async => 'ok');

      expect(result, 'ok');
      controller.onClose();
    });

    test('onInit reconfigures an engine created before initialization', () {
      final controller = TestTasksController()..tasksEngine;
      controller.didAttachToScope(Ls.currentScope, key: 'test');
      controller.onInit();
      controller.onClose();
    });

    test('throws a clear error after the controller is closed', () {
      final controller = TestTasksController();
      controller.onInit();
      controller.onClose();

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

      final result = await controller.tasksEngine.schedule(() async => 42);

      expect(result, 42);
      controller.onClose();
    });

    test('lazy-inits isBusy and totalProgress before onInit', () {
      final controller = TestReactiveTasksController();

      expect(controller.isBusy.value, isFalse);
      expect(controller.totalProgress.value, 0.0);

      controller.onClose();
    });

    test('throws a clear error after the controller is closed', () {
      final controller = TestReactiveTasksController();
      controller.onInit();
      controller.onClose();

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
