import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestService extends LevitController with LevitTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

class TestController extends LevitController with LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

class MixedController extends LevitController
    with LevitTasksMixin, LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

// Helpers for default values
class DefaultService extends LevitController with LevitTasksMixin {}

class DefaultController extends LevitController with LevitReactiveTasksMixin {}

void main() {
  group('LevitTasksMixin', () {
    late TestService service;

    setUp(() {
      service = TestService();
      service.onInit();
    });

    test('executes simple task', () async {
      final result = await service.tasksEngine.schedule(() async => 'success');
      expect(result, 'success');
    });

    test('respects concurrency limit and queue priority', () async {
      final completers = <String, Completer>{
        't1': Completer(),
        't2': Completer(),
        't3': Completer(),
        't4': Completer(),
      };
      final executionOrder = <String>[];

      Future<void> run(String id, TaskPriority priority) {
        return service.tasksEngine.schedule(
          () async {
            executionOrder.add('start_$id');
            await completers[id]!.future;
            executionOrder.add('end_$id');
          },
          id: id,
          priority: priority,
        );
      }

      // Max concurrent is 2
      // Start 2 tasks (Active: t1, t2)
      run('t1', TaskPriority.normal);
      run('t2', TaskPriority.normal);

      await Future.delayed(Duration.zero);
      expect(executionOrder, containsAll(['start_t1', 'start_t2']));
      expect(executionOrder, isNot(contains('start_t3')));

      // Start 2 more (Queued: t3, t4)
      // t3 is Low, t4 is High
      run('t3', TaskPriority.low);
      run('t4', TaskPriority.high);

      await Future.delayed(Duration.zero);
      // Still only t1, t2 active
      expect(executionOrder, isNot(contains('start_t3')));
      expect(executionOrder, isNot(contains('start_t4')));

      // Finish t1 -> slot opens -> t4 (High) should start
      completers['t1']!.complete();
      await Future.delayed(Duration.zero);
      expect(executionOrder, contains('end_t1'));
      expect(executionOrder, contains('start_t4')); // Priority worked
      expect(executionOrder, isNot(contains('start_t3')));

      // Finish t2 -> slot opens -> t3 (Low) starts
      completers['t2']!.complete();
      await Future.delayed(Duration.zero);
      expect(executionOrder, contains('end_t2'));
      expect(executionOrder, contains('start_t3'));

      // Cleanup
      completers['t3']!.complete();
      completers['t4']!.complete();
    });

    test('retries on failure', () async {
      int attempts = 0;
      try {
        await service.tasksEngine.schedule(
          () async {
            attempts++;
            if (attempts < 3) throw 'fail';
            return 'success';
          },
          retries: 3,
          retryDelay: const Duration(milliseconds: 1), // Fast retry
        );
      } catch (e) {
        fail('Should not throw');
      }
      expect(attempts, 3);
    });

    test('linear backoff', () async {
      int attempts = 0;
      await service.tasksEngine.schedule(
        () async {
          attempts++;
          if (attempts < 3) throw 'fail';
          return 'success';
        },
        retries: 2,
        useExponentialBackoff: false,
        retryDelay: const Duration(milliseconds: 1),
      );
      expect(attempts, 3);
    });

    test('fails after max retries', () async {
      int attempts = 0;
      try {
        await service.tasksEngine.schedule(
          () async {
            attempts++;
            throw 'fail';
          },
          retries: 2,
          retryDelay: const Duration(milliseconds: 1),
        );
      } catch (e) {
        // Expected rethrow
      }
      expect(attempts, 3); // Initial + 2 retries
    });

    test('uses default maxConcurrentTasks', () {
      final defaultService = DefaultService()..onInit();
      expect(defaultService.maxConcurrentTasks, 100000);
    });

    test('cancels active task', () async {
      final completer = Completer();
      final done = Completer();
      service.tasksEngine.schedule(() async {
        await completer.future;
        done.complete();
      }, id: 't1');

      await Future.delayed(Duration.zero);
      service.tasksEngine.cancel('t1');
      completer.complete();
      await expectLater(done.future, completes);
    });

    test('cancels queued task', () async {
      final b1 = Completer();
      final b2 = Completer();
      // Saturate concurrency (max=2)
      service.tasksEngine.schedule(() => b1.future, id: 'b1');
      service.tasksEngine.schedule(() => b2.future, id: 'b2');

      bool ran = false;
      service.tasksEngine.schedule(() async => ran = true, id: 'queued');

      service.tasksEngine.cancel('queued');
      b1.complete();
      b2.complete();
      await Future.delayed(Duration.zero);

      expect(ran, false);
    });

    test('cancels active task specifically during retry delay (L299)',
        () async {
      final started = Completer();
      int attempts = 0;
      bool onErrorCalled = false;
      final future = service.tasksEngine.schedule(
        () async {
          attempts++;
          if (attempts == 1) {
            started.complete();
            throw 'fail';
          }
          return 'success';
        },
        id: 'retry_cancel_loop',
        retries: 1,
        retryDelay: const Duration(milliseconds: 200),
        onError: (e, s) {
          onErrorCalled = true;
        },
      );

      await started.future;
      // Now it's likely finished the throw and is entering the Future.delayed(200ms)
      await Future.delayed(const Duration(milliseconds: 50));

      service.tasksEngine.cancel('retry_cancel_loop');

      final result = await future;
      expect(result, null);
      expect(attempts, 1);
      expect(onErrorCalled, false); // Proves it hit L299, not L319
    });

    test('cancelAllTasks iterates active tasks', () async {
      final c1 = Completer();
      final c2 = Completer();
      service.tasksEngine.schedule(() => c1.future, id: 'a1');
      service.tasksEngine.schedule(() => c2.future, id: 'a2');
      service.tasksEngine.cancelAll();
      c1.complete();
      c2.complete();
    });

    test('queued task error completes with error (L357)', () async {
      final b1 = Completer();
      final b2 = Completer();
      // Saturate concurrency (max=2)
      service.tasksEngine.schedule(() => b1.future);
      service.tasksEngine.schedule(() => b2.future);

      final future = service.tasksEngine.schedule(
        () => throw 'error',
        onError: (e, s) => throw 'bubble',
      );

      b1.complete();
      b2.complete();

      await expectLater(future, throwsA('bubble'));
    });

    test('uses onTaskError', () async {
      bool caught = false;
      service.tasksEngine.config(onTaskError: (e, s) => caught = true);
      try {
        await service.tasksEngine.schedule(() => throw 'error');
      } catch (_) {}
      expect(caught, true);
    });
  });

  group('LevitReactiveTasksMixin', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
      controller.onInit();
    });

    test('updates tasks map state', () async {
      final completer = Completer();
      final future = controller.runTask(() async {
        await completer.future;
        return 'done';
      }, id: 'task1');

      expect(controller.tasks['task1']?.status, isA<LxWaiting>());

      completer.complete();
      await future;

      expect(controller.tasks['task1']?.status, isA<LxSuccess>());
      expect((controller.tasks['task1']?.status as LxSuccess).value, 'done');
    });

    test('updates totalProgress', () async {
      final c1 = Completer();
      final c2 = Completer();

      controller.runTask(() => c1.future, id: 't1', weight: 1.0);
      controller.runTask(() => c2.future, id: 't2', weight: 1.0);

      expect(controller.totalProgress.value, 0.0);

      controller.updateTaskProgress('t1', 0.5);
      expect(controller.totalProgress.value, 0.25);

      c1.complete();
      await Future.delayed(Duration.zero);
      expect(controller.totalProgress.value, 0.5);

      c2.complete();
      await Future.delayed(Duration.zero);
      expect(controller.totalProgress.value, 1.0);
    });

    test('uses default maxConcurrentTasks', () {
      final c = DefaultController()..onInit();
      expect(c.maxConcurrentTasks, 100000);
    });

    test('clearTask removes task and cancels it', () async {
      final c = Completer();
      controller.runTask(() => c.future, id: 't1');
      expect(controller.tasks.containsKey('t1'), true);

      controller.clearTask('t1');
      expect(controller.tasks.containsKey('t1'), false);
    });

    test('clearCompleted removes success/idle', () async {
      controller.tasks['s'] = TaskDetails(status: LxSuccess(1));
      controller.tasks['i'] = TaskDetails(status: LxIdle());
      controller.tasks['w'] = TaskDetails(status: LxWaiting());

      controller.clearCompleted();

      expect(controller.tasks.containsKey('s'), false);
      expect(controller.tasks.containsKey('i'), false);
      expect(controller.tasks.containsKey('w'), true);
    });

    test('onTaskError catches errors', () async {
      bool caught = false;
      controller.onTaskError = (e, s) => caught = true;
      try {
        await controller.runTask(() => throw 'fail', id: 't1');
      } catch (_) {}
      expect(controller.tasks['t1']?.status, isA<LxError>());
      expect(caught, true);
    });

    test('cancelAllTasks works from controller', () async {
      controller.cancelAllTasks();
    });

    test('protects active tasks during history pruning', () async {
      final c = TestController()..onInit();
      // Set history limit to 2 for testing
      // Actually we'd need to mock the getter if we wanted to change it mid-test,
      // but we can just fill it up.

      final completers = <Completer>[];
      for (var i = 0; i < 50; i++) {
        final comp = Completer();
        completers.add(comp);
        c.runTask(() => comp.future, id: 'task_$i');
      }

      expect(c.tasks.length, 50);

      // Try to add one more. History is 50.
      // All current 50 are LxWaiting, so orElse: () => '' should trigger.
      final nextComp = Completer();
      c.runTask(() => nextComp.future, id: 'task_51');

      expect(c.tasks.length, 51); // Should grow because it can't prune active

      // Finish one task
      completers[0].complete();
      await Future.delayed(Duration.zero);

      // Now add another. It should prune the completed 'task_0'.
      c.runTask(() => Completer().future, id: 'task_52');
      expect(c.tasks.containsKey('task_0'), false);
      expect(c.tasks.length, 51);
    });

    test('supports mixing both TasksMixins without name collisions', () async {
      final mixed = MixedController()..onInit();
      final r1 = await mixed.runTask(() async => 'basic');
      final r2 = await (mixed as LevitReactiveTasksMixin)
          .runTask(() async => 'reactive', id: 'r1');

      expect(r1, 'basic');
      expect(r2, 'reactive');
      expect(mixed.tasks.containsKey('r1'), true);
    });
  });
}
