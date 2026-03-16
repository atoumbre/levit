import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestTasksController extends LevitController with LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 1; // Limit for testing queue
}

class CleanupController extends LevitController with LevitReactiveTasksMixin {
  @override
  Duration? get autoCleanupDelay => const Duration(hours: 24);
}

class SimpleTasksController extends LevitController with LevitTasksMixin {
  @override
  int get maxConcurrentTasks => 2;
}

// Concrete implementation to test abstract base if needed,
// but InMemoryTaskCacheProvider already calls super.
class VoidCacheProvider extends LevitTaskCacheProvider {
  const VoidCacheProvider() : super();
  @override
  Future<void> delete(String key) async {}
  @override
  Future<Map<String, dynamic>?> read(String key) async => null;
  @override
  Future<void> write(String key, Map<String, dynamic> data) async {}
}

void main() {
  group('LevitReactiveTasksMixin', () {
    late TestTasksController controller;

    setUp(() {
      controller = TestTasksController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('isBusy is reactive and notifies listeners', () async {
      final completer = Completer<void>();
      bool? lastBusy = controller.isBusy.value;

      // Watch isBusy
      final watcher = LxWorker(controller.isBusy, (busy) {
        lastBusy = busy;
      });

      expect(lastBusy, isFalse);

      final task = controller.runTask(() => completer.future);
      expect(lastBusy, isTrue,
          reason: 'Listener should be notified of busy state');

      completer.complete();
      await task;
      expect(lastBusy, isFalse,
          reason: 'Listener should be notified of idle state');

      watcher.close();
    });

    test('started flag reflects if task has begun execution', () async {
      final completer = Completer<void>();
      final task = controller.runTask(() => completer.future, id: 'start_test');

      // It might be LxWaiting but not yet started by the engine if maxConcurrent is hit
      // In this test, maxConcurrent is 1, so it should start immediately.
      expect(controller.tasks['start_test']?.started, isTrue);

      completer.complete();
      await task;
    });

    test('isBusy correctly reflects active and queued tasks', () async {
      final completer = Completer<void>();

      expect(controller.isBusy.value, isFalse);

      // Start task 1 (active)
      final task1 = controller.runTask(() async {
        await completer.future;
      });

      expect(controller.isBusy.value, isTrue,
          reason: 'Busy when task is active');

      // Start task 2 (queued)
      final task2 = controller.runTask(() async {
        return 'done';
      });

      expect(controller.isBusy.value, isTrue,
          reason: 'Busy when task is queued');

      completer.complete();
      await task1;
      await task2;

      expect(controller.isBusy.value, isFalse,
          reason: 'Not busy when all tasks finished');
    });

    test('totalProgress calculates correctly with weights', () async {
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      expect(controller.totalProgress.value, 0.0);

      controller.runTask(() => c1.future, id: 't1', weight: 1.0);
      controller.runTask(() => c2.future, id: 't2', weight: 4.0);

      expect(controller.totalProgress.value, 0.0);

      controller.updateTaskProgress('t1', 1.0); // 1.0 * 1.0 = 1.0
      expect(controller.totalProgress.value, 1.0 / 5.0);

      controller.updateTaskProgress('t2', 0.5); // 0.5 * 4.0 = 2.0
      expect(controller.totalProgress.value, (1.0 + 2.0) / 5.0);

      c1.complete();
      c2.complete();
      await Future.delayed(Duration.zero);
      expect(controller.totalProgress.value, 1.0);
    });

    test('caching policy handles expiration and deserialization failure',
        () async {
      final cachePolicy = TaskCachePolicy<int>(
        ttl: const Duration(seconds: 1),
        toJson: (v) => {'v': v},
        fromJson: (json) {
          if (json['v'] == -1) throw Exception('fail');
          return json['v'] as int;
        },
      );

      // 1. Success write/read
      await controller.runTask(() async => 42,
          id: 'cache_test', cachePolicy: cachePolicy);
      expect(controller.tasks['cache_test']?.status is LxSuccess, isTrue);

      final result = await controller.runTask(() async => 99,
          id: 'cache_test', cachePolicy: cachePolicy);
      expect(result, 42, reason: 'Should return cached value');

      // 2. Deserialization failure
      await controller.tasksEngine.cacheProvider.write('cache_fail', {
        'expiresAt':
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'data': {'v': -1},
      });
      final failResult = await controller.runTask(() async => 100,
          id: 'cache_fail', cachePolicy: cachePolicy);
      expect(failResult, 100,
          reason: 'Should run task if cache deserialization fails');

      // 3. Expiration
      await controller.tasksEngine.cacheProvider.write('cache_expire', {
        'expiresAt': DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        'data': {'v': 200},
      });
      final expireResult = await controller.runTask(() async => 300,
          id: 'cache_expire', cachePolicy: cachePolicy);
      expect(expireResult, 300, reason: 'Should run task if cache expired');

      // Coverage for LevitTaskCacheProvider const constructor
      const VoidCacheProvider();
    });

    test('autoCleanupDelay triggers timer and onClose cancels it', () async {
      final cleanupController = CleanupController();
      cleanupController.onInit();

      await cleanupController.runTask(() async => 'done', id: 'auto_clean');
      expect(cleanupController.tasks.containsKey('auto_clean'), isTrue);

      cleanupController
          .onClose(); // This should cover the timer.cancel() loop (line 479)
    });
  });

  group('LevitTasksMixin (Non-Reactive)', () {
    test('runTask executes and handles caching', () async {
      final controller = SimpleTasksController();
      controller.onInit();

      final cachePolicy = TaskCachePolicy<String>(
        ttl: const Duration(hours: 1),
        toJson: (v) => {'data': v},
        fromJson: (j) => j['data'] as String,
      );

      final r1 = await controller.tasksEngine
          .schedule(() async => 'hello', id: 't1', cachePolicy: cachePolicy);
      expect(r1, 'hello');

      final r2 = await controller.tasksEngine
          .schedule(() async => 'world', id: 't1', cachePolicy: cachePolicy);
      expect(r2, 'hello');

      controller.onClose();
    });
  });
}
