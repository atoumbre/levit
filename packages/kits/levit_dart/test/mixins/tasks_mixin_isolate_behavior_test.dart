import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

// Top-level function for Isolate tests
String _testIsolateTask(
  Object? input,
  LevitIsolateTaskContext context,
) =>
    'isolate_result';

int _progressIsolateTask(int input, LevitIsolateTaskContext context) {
  context.reportProgress(.5);
  return input * 2;
}

Future<String> _cancellableIsolateTask(
  Object? input,
  LevitIsolateTaskContext context,
) async {
  context.reportProgress(.1);
  await context.cancelled;
  context.throwIfCancelled();
  return 'unreachable';
}

class TestIsolateTasksController extends LevitController with LevitTasksMixin {}

class TestIsolateReactiveTasksController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  group('TasksMixin Isolate Behavior', () {
    test('LevitTasksMixin.runIsolateTask executes and returns result',
        () async {
      await Levit.runInScope<void>(() async {
        final controller = Levit.put(() => TestIsolateTasksController());
        final result = await controller.tasksEngine.scheduleIsolate(
          _testIsolateTask,
          null,
          debugName: 'test_isolate',
        );
        expect(result, 'isolate_result');
      }, name: 'isolate_task_test');
    });

    test('LevitReactiveTasksMixin.runIsolateTask executes and returns result',
        () async {
      await Levit.runInScope<void>(() async {
        final controller = Levit.put(
          () => TestIsolateReactiveTasksController(),
        );
        final result = await controller.runIsolateTask(
          _testIsolateTask,
          null,
          debugName: 'test_reactive_isolate',
        );
        expect(result, 'isolate_result');

        expect(
          controller.tasks.values.any((d) => d.status is LxSuccess),
          isTrue,
        );
      }, name: 'reactive_isolate_task_test');
    });

    test('LevitTaskCacheProvider constructor coverage', () {
      // Line 30: const LevitTaskCacheProvider();
      const provider = _VoidCacheProvider();
      expect(provider, isA<LevitTaskCacheProvider>());
    });

    test('isolate tasks bridge progress and structured events', () async {
      final progress = <double>[];
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );

      final result = await engine.scheduleIsolate(
        _progressIsolateTask,
        21,
        onProgress: progress.add,
      );

      expect(result, 42);
      expect(progress, [.5]);
      expect(events.every((event) => event.runsInIsolate), isTrue);
    });

    test('isolate cancellation is cooperative', () async {
      final progressArrived = Completer<void>();
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final execution = engine.submitIsolate(
        _cancellableIsolateTask,
        null,
        onProgress: (_) => progressArrived.complete(),
      );

      await progressArrived.future;
      execution.cancel();
      expect(await execution.result, isNull);
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
