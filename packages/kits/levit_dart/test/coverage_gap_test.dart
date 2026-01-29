import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController with LevitTasksMixin {}

class ReactiveTestController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  group('LevitTasksMixin Coverage', () {
    test('cancelAllTasks called directly', () {
      final controller = TestController();
      controller.onInit();
      // Should not throw
      controller.cancelAllTasks();
      controller.onClose();
    });

    test('onClose calls cancelAllTasks', () {
      final controller = TestController();
      controller.onInit();
      controller.onClose();
      // Verifying no errors, internal state logic is hidden but covered by execution lines
    });
  });

  group('LevitReactiveTasksMixin Coverage', () {
    test('Duplicate task ID throws StateError', () async {
      final controller = ReactiveTestController();
      controller.onInit();

      // Start a task that hangs
      controller.runTask(() async {
        await Future.delayed(const Duration(seconds: 1));
      }, id: 'task1');

      // Try to start another with same ID
      expect(
        () => controller.runTask(() async {}, id: 'task1'),
        throwsA(isA<StateError>()),
      );

      controller.onClose();
    });

    test('cancelAllTasks called directly', () {
      final controller = ReactiveTestController();
      controller.onInit();
      controller.cancelAllTasks();
      controller.onClose();
    });

    test('onClose calls cancelAllTasks', () {
      final controller = ReactiveTestController();
      controller.onInit();
      controller.onClose();
    });

    test('clearTask cancels and removes task', () async {
      final controller = ReactiveTestController();
      controller.onInit();

      controller.runTask(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      }, id: 'task1');

      expect(controller.tasks.containsKey('task1'), isTrue);

      controller.clearTask('task1');

      expect(controller.tasks.containsKey('task1'), isFalse);

      controller.onClose();
    });
  });
}
