import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class MockCacheProvider extends LevitTaskCacheProvider {
  final Map<String, Map<String, dynamic>> storage = {};
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    writeCount++;
    storage[key] = data;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    readCount++;
    return storage[key];
  }

  @override
  Future<void> delete(String key) async {
    storage.remove(key);
  }
}

class CustomCacheController extends LevitController with LevitTasksMixin {
  final MockCacheProvider mockCache = MockCacheProvider();

  @override
  LevitTaskCacheProvider? get taskCacheProvider => mockCache;
}

class CustomReactiveCacheController extends LevitController
    with LevitReactiveTasksMixin {
  final MockCacheProvider mockCache = MockCacheProvider();

  @override
  LevitTaskCacheProvider? get taskCacheProvider => mockCache;
}

void main() {
  test('LevitTasksMixin uses overridden taskCacheProvider', () async {
    final controller = CustomCacheController();
    controller.onInit();

    final policy = TaskCachePolicy<int>(
      ttl: const Duration(minutes: 5),
      toJson: (v) => {'val': v},
      fromJson: (j) => j['val'] as int,
    );

    // Initial run
    await controller.tasksEngine
        .schedule(() async => 100, id: 'key1', cachePolicy: policy);
    expect(controller.mockCache.writeCount, 1);

    // Second run should hit the mock cache
    final result = await controller.tasksEngine
        .schedule(() async => 200, id: 'key1', cachePolicy: policy);
    expect(result, 100);
    expect(controller.mockCache.readCount, 2);

    controller.onClose();
  });

  test('LevitReactiveTasksMixin uses overridden taskCacheProvider', () async {
    final controller = CustomReactiveCacheController();
    controller.onInit();

    final policy = TaskCachePolicy<int>(
      ttl: const Duration(minutes: 5),
      toJson: (v) => {'val': v},
      fromJson: (j) => j['val'] as int,
    );

    // Initial run
    await controller.runTask(() async => 300, id: 'key2', cachePolicy: policy);
    expect(controller.mockCache.writeCount, 1);

    // Second run should hit the mock cache
    final result = await controller.runTask(() async => 400,
        id: 'key2', cachePolicy: policy);
    expect(result, 300);
    expect(controller.mockCache.readCount, 2);

    controller.onClose();
  });
}
