import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_dart/levit_dart.dart';

// Top-level function for Isolate tests
String _testIsolateTask() => 'isolate_result';

class TestIsolateTasksController extends LevitController with LevitTasksMixin {}

class TestIsolateReactiveTasksController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  group('TasksMixin Isolate Behavior', () {
    test('LevitTasksMixin.runIsolateTask executes and returns result',
        () async {
      final controller = TestIsolateTasksController();
      controller.onInit();

      final result = await controller.runIsolateTask(_testIsolateTask,
          debugName: 'test_isolate');
      expect(result, 'isolate_result');

      controller.onClose();
    });

    test('LevitReactiveTasksMixin.runIsolateTask executes and returns result',
        () async {
      final controller = TestIsolateReactiveTasksController();
      controller.onInit();

      final result = await controller.runIsolateTask(_testIsolateTask,
          debugName: 'test_reactive_isolate');
      expect(result, 'isolate_result');

      // Verify reactive state was updated
      expect(controller.tasks.values.any((s) => s is LxSuccess), isTrue);

      controller.onClose();
    });

    test('LevitTaskCacheProvider constructor coverage', () {
      // Line 30: const LevitTaskCacheProvider();
      const provider = _VoidCacheProvider();
      expect(provider, isA<LevitTaskCacheProvider>());
    });
  });
}

class _VoidCacheProvider extends LevitTaskCacheProvider {
  const _VoidCacheProvider() : super();
  @override
  Future<void> delete(String key) async {}
  @override
  Future<Map<String, dynamic>?> read(String key) async => null;
  @override
  Future<void> write(String key, Map<String, dynamic> data) async {}
}
