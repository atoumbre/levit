import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

// Mock controller using the mixin
class TestTaskController extends LevitController with LevitReactiveTasksMixin {
  @override
  Duration? get autoCleanupDelay => const Duration(milliseconds: 50);
}

void main() {
  test('Auto-cleanup removes tasks after delay', () async {
    final controller = TestTaskController();
    controller.onInit();

    // Run a task
    await controller.runTask(() async => 'success', id: 'task1');

    // Immediately after, it should exist and be success
    expect(controller.tasks.containsKey('task1'), isTrue);
    expect(controller.tasks['task1']?.status, isA<LxSuccess>());

    // Wait for cleanup delay (50ms) + buffer
    await Future.delayed(const Duration(milliseconds: 100));

    // Should be gone
    expect(controller.tasks.containsKey('task1'), isFalse);

    controller.onClose();
  });
}
