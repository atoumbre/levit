import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class _ReactiveTaskController extends LevitController
    with LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

void main() {
  test('reactive selectors filter category and blocking state', () async {
    await Levit.runInScope<void>(() async {
      final controller = Levit.put(() => _ReactiveTaskController());
      final blocker = Completer<void>();
      final reported = Completer<void>();
      final task = controller.runTask<String>(
        (context) async {
          context.reportProgress(.4);
          reported.complete();
          await blocker.future;
          return 'done';
        },
        id: 'sync',
        weight: 2,
        metadata: const LevitTaskMetadata(
          category: 'sync',
          blocksUserInteraction: true,
        ),
      );

      await reported.future;
      expect(controller.taskDetails('sync')?.executionId, isNotNull);
      expect(controller.taskStatus<String>('sync'), isA<LxWaiting>());
      expect(controller.isTaskRunning('sync'), isTrue);
      expect(controller.taskProgress('sync'), .4);
      expect(controller.isBusyWhere(category: 'sync'), isTrue);
      expect(controller.isBusyWhere(category: 'media'), isFalse);
      expect(
        controller.isBusyWhere(blocksUserInteraction: true),
        isTrue,
      );
      expect(controller.progressWhere(category: 'sync'), .4);
      expect(controller.hasBlockingTasks.value, isTrue);
      expect(controller.taskStatus<int>('missing'), isA<LxIdle<int>>());
      expect(controller.taskProgress('missing'), 0);

      blocker.complete();
      expect(await task, 'done');
      expect(controller.isTaskRunning('sync'), isFalse);
      expect(controller.taskStatus<String>('sync'), isA<LxSuccess<String>>());
      expect(controller.progressWhere(category: 'sync'), 1);
    }, name: 'reactive_task_selectors');
  });

  test('restart execution identity prevents stale state publication', () async {
    await Levit.runInScope<void>(() async {
      final controller = Levit.put(() => _ReactiveTaskController());
      final oldGate = Completer<void>();
      final old = controller.runTask(
        (_) async {
          await oldGate.future;
          return 'old';
        },
        id: 'search',
      );
      final replacement = controller.runTask(
        (_) => 'new',
        id: 'search',
        conflictPolicy: TaskConflictPolicy.restart,
      );

      expect(await replacement, 'new');
      expect(
        (controller.taskStatus<String>('search') as LxSuccess<String>).value,
        'new',
      );
      final replacementId = controller.taskDetails('search')?.executionId;

      oldGate.complete();
      expect(await old, isNull);
      expect(controller.taskDetails('search')?.executionId, replacementId);
      expect(
        (controller.taskStatus<String>('search') as LxSuccess<String>).value,
        'new',
      );
    }, name: 'reactive_task_restart');
  });

  test('manual progress is validated', () async {
    await Levit.runInScope<void>(() async {
      final controller = Levit.put(() => _ReactiveTaskController());
      final blocker = Completer<void>();
      final task = controller.runTask((_) => blocker.future, id: 'manual');

      controller.updateTaskProgress('manual', .75);
      expect(controller.taskProgress('manual'), .75);
      expect(
        () => controller.updateTaskProgress('manual', double.infinity),
        throwsRangeError,
      );
      controller.updateTaskProgress('absent', .5);

      controller.cancelTask('manual');
      blocker.complete();
      await task;
    }, name: 'reactive_task_progress');
  });
}
