import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class _BasicTasksController extends LevitController with LevitTasksMixin {}

class _ReactiveTasksController extends LevitController
    with LevitReactiveTasksMixin {}

void main() {
  group('LevitTasksMixin conflict-policy helpers', () {
    test('runLatest restarts in-flight task with the same id', () async {
      final scope = Levit.createScope('tasks-run-latest');
      final controller = scope.put(_BasicTasksController.new);

      final firstStarted = Completer<void>();
      final firstCancelled = Completer<void>();
      final first = controller.runLatest<String>('search', (ctx) async {
        firstStarted.complete();
        await ctx.cancelled;
        firstCancelled.complete();
        ctx.throwIfCancelled();
        return 'first';
      });
      unawaited(first.catchError((_) => ''));

      await firstStarted.future;
      final second = controller.runLatest<String>('search', (ctx) async {
        return 'second';
      });

      await firstCancelled.future;
      expect(await second, 'second');
      await expectLater(first, throwsA(isA<LevitTaskCancelledException>()));

      await scope.dispose();
    });

    test('runDrop drops overlapping submissions for the same id', () async {
      final scope = Levit.createScope('tasks-run-drop');
      final controller = scope.put(_BasicTasksController.new);

      final started = Completer<void>();
      final release = Completer<void>();
      final first = controller.runDrop<String>('submit', (ctx) async {
        started.complete();
        await release.future;
        return 'submitted';
      });

      await started.future;
      await expectLater(
        controller.runDrop<String>('submit', (_) async => 'duplicate'),
        throwsA(isA<LevitTaskDroppedException>()),
      );

      release.complete();
      expect(await first, 'submitted');
      await scope.dispose();
    });

    test('runQueued executes overlapping submissions in FIFO order', () async {
      final scope = Levit.createScope('tasks-run-queued');
      final controller = scope.put(_BasicTasksController.new);

      final order = <String>[];
      final firstRelease = Completer<void>();
      final first = controller.runQueued<String>('queue', (_) async {
        order.add('start-1');
        await firstRelease.future;
        order.add('end-1');
        return '1';
      });
      final second = controller.runQueued<String>('queue', (_) async {
        order.add('start-2');
        order.add('end-2');
        return '2';
      });

      await Future<void>.delayed(Duration.zero);
      expect(order, ['start-1']);

      firstRelease.complete();
      expect(await Future.wait([first, second]), ['1', '2']);
      expect(order, ['start-1', 'end-1', 'start-2', 'end-2']);
      await scope.dispose();
    });

    test('runJoin shares the result of an in-flight execution', () async {
      final scope = Levit.createScope('tasks-run-join');
      final controller = scope.put(_BasicTasksController.new);

      var runs = 0;
      final started = Completer<void>();
      final release = Completer<void>();

      final first = controller.runJoin<int>('fetch', (_) async {
        runs++;
        started.complete();
        await release.future;
        return 42;
      });
      await started.future;

      final second = controller.runJoin<int>('fetch', (_) async {
        runs++;
        return 99;
      });

      release.complete();
      expect(await Future.wait([first, second]), [42, 42]);
      expect(runs, 1);
      await scope.dispose();
    });

    test(
      'runCoalesceLatest runs current execution and coalesces trailing calls',
      () async {
        final scope = Levit.createScope('tasks-run-coalesce');
        final controller = scope.put(_BasicTasksController.new);

        final executed = <String>[];
        final started = Completer<void>();
        final release = Completer<void>();

        final first = controller.runCoalesceLatest<String>('save', (_) async {
          executed.add('v1');
          started.complete();
          await release.future;
          return 'v1';
        });
        await started.future;

        final middle = controller.runCoalesceLatest<String>('save', (_) async {
          executed.add('v2');
          return 'v2';
        });
        unawaited(middle.catchError((_) => ''));

        final trailing = controller.runCoalesceLatest<String>('save', (
          _,
        ) async {
          executed.add('v3');
          return 'v3';
        });

        release.complete();
        expect(await first, 'v1');
        expect(await trailing, 'v3');
        expect(executed, ['v1', 'v3']);
        await scope.dispose();
      },
    );
  });

  group('LevitReactiveTasksMixin conflict-policy helpers', () {
    test(
      'forwards conflict policies and reactive weight tracking across helpers',
      () async {
        final scope = Levit.createScope('reactive-tasks-helpers');
        final controller = scope.put(_ReactiveTasksController.new);

        final started = Completer<void>();
        final release = Completer<void>();
        final first = controller.runJoin<String>('sync', (ctx) async {
          started.complete();
          ctx.reportProgress(0.5);
          await release.future;
          return 'synced';
        }, weight: 2.0);
        await started.future;

        expect(controller.isBusy(), isTrue);
        expect(controller.taskDetails('sync')?.weight, 2.0);

        final joined = controller.runJoin<String>('sync', (_) async => 'other');
        release.complete();
        expect(await Future.wait([first, joined]), ['synced', 'synced']);
        expect(
          controller.taskStatus<String>('sync'),
          const LxSuccess('synced'),
        );

        expect(await controller.runLatest<int>('latest', (_) async => 1), 1);
        expect(await controller.runDrop<int>('drop', (_) async => 2), 2);
        expect(await controller.runQueued<int>('queued', (_) async => 3), 3);
        expect(
          await controller.runCoalesceLatest<int>('coalesce', (_) async => 4),
          4,
        );

        await scope.dispose();
      },
    );
  });
}
