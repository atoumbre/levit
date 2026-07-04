import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class CacheController extends LevitController with LevitTasksMixin {
  int callCount = 0;

  Future<int> fetchData() async {
    callCount++;
    return 42;
  }
}

class ReactiveCacheController extends LevitController
    with LevitReactiveTasksMixin {
  int callCount = 0;

  Future<int> fetchData() async {
    callCount++;
    return 42;
  }
}

void main() {
  group('Task Caching - LevitTasksMixin', () {
    test('returns cached result on second call', () async {
      final controller = CacheController();
      controller.onInit();

      final policy = TaskCachePolicy<int>(
        ttl: const Duration(minutes: 5),
        toJson: (v) => {'val': v},
        fromJson: (j) => j['val'] as int,
      );

      // First call - execution
      final r1 = await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task1',
        cachePolicy: policy,
      );

      expect(r1, 42);
      expect(controller.callCount, 1);

      // Second call - cache hit
      final r2 = await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task1',
        cachePolicy: policy,
      );

      expect(r2, 42);
      expect(controller.callCount, 1); // Should NOT have called fetchData again

      controller.onClose();
    });

    test('re-executes after TTL expiry', () async {
      final controller = CacheController();
      controller.onInit();

      final policy = TaskCachePolicy<int>(
        ttl: const Duration(milliseconds: 10),
        toJson: (v) => {'val': v},
        fromJson: (j) => j['val'] as int,
      );

      await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task_ttl',
        cachePolicy: policy,
      );
      expect(controller.callCount, 1);

      await Future.delayed(const Duration(milliseconds: 20));

      await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task_ttl',
        cachePolicy: policy,
      );
      expect(controller.callCount, 2); // Should have re-executed

      controller.onClose();
    });
  });

  group('Task Caching - LevitReactiveTasksMixin', () {
    test('updates reactive state on cache hit', () async {
      final controller = ReactiveCacheController();
      controller.onInit();

      final policy = TaskCachePolicy<int>(
        ttl: const Duration(minutes: 5),
        toJson: (v) => {'val': v},
        fromJson: (j) => j['val'] as int,
      );

      // Fill cache
      await controller.runTask(
        controller.fetchData,
        id: 'shared_key',
        cachePolicy: policy,
      );

      // Verify reactive state is success
      expect(controller.tasks['shared_key']?.status, isA<LxSuccess<int>>());
      expect(controller.callCount, 1);

      // Clear local state but keep cache (since it's static/shared in this test instance)
      controller.tasks.clear();

      // Trigger cache hit
      final result = await controller.runTask(
        () async =>
            999, // Different task content, but same ID/Key should hit cache
        id: 'shared_key',
        cachePolicy: policy,
      );

      expect(result, 42); // Should be the CACHED 42, not 999
      expect(controller.callCount, 1); // fetchData not called again

      // Verify reactive state was updated to success despite cache hit
      expect(controller.tasks['shared_key']?.status, isA<LxSuccess<int>>());
      expect((controller.tasks['shared_key']?.status as LxSuccess).value, 42);

      controller.onClose();
    });
  });

  group('Task Caching - Deserialization Error', () {
    test('treats deserialization failure as cache miss and deletes entry',
        () async {
      final controller = CacheController();
      controller.onInit();

      final policy = TaskCachePolicy<int>(
        ttl: const Duration(minutes: 5),
        toJson: (v) => {'val': v},
        fromJson: (j) => throw FormatException('Bad data'),
      );

      // First call sets cache
      await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task_fail',
        cachePolicy: policy,
      );

      // Second call fails to deserialize
      final result = await controller.tasksEngine.schedule(
        controller.fetchData,
        id: 'task_fail',
        cachePolicy: policy,
      );

      expect(result, 42);
      expect(controller.callCount, 2); // Should have re-called fetchData

      controller.onClose();
    });
  });
}
