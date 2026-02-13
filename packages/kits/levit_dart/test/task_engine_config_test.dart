import 'dart:async';
import 'dart:mirrors';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class MockCache extends LevitTaskCacheProvider {
  final Map<String, Map<String, dynamic>> storage = {};
  @override
  Future<void> write(String key, Map<String, dynamic> data) async =>
      storage[key] = data;
  @override
  Future<Map<String, dynamic>?> read(String key) async => storage[key];
  @override
  Future<void> delete(String key) async => storage.remove(key);
}

void main() {
  group('LevitTaskEngine.config', () {
    late LevitTaskEngine engine;

    setUp(() {
      engine = LevitTaskEngine(maxConcurrent: 1);
    });

    test('updates maxConcurrent and processes queue', () async {
      final c1 = Completer<void>();
      final c2 = Completer<void>();
      final c3 = Completer<void>();

      int runningCount = 0;

      Future<void> task(Completer<void> c) async {
        runningCount++;
        await c.future;
        runningCount--;
      }

      engine.schedule(() => task(c1));
      engine.schedule(() => task(c2));
      engine.schedule(() => task(c3));

      await Future.delayed(Duration.zero);
      expect(runningCount, 1, reason: 'Only 1 task should run initially');

      engine.config(maxConcurrent: 2);
      await Future.delayed(Duration.zero);
      expect(runningCount, 2,
          reason: '2 tasks should run after updating maxConcurrent');

      engine.config(maxConcurrent: 3);
      await Future.delayed(Duration.zero);
      expect(runningCount, 3, reason: 'All 3 tasks should run eventually');

      c1.complete();
      c2.complete();
      c3.complete();
    });

    test('updates onTaskError', () async {
      Object? lastError;
      engine.config(onTaskError: (e, s) => lastError = e);

      try {
        await engine.schedule(() => throw 'error1');
      } catch (_) {}
      expect(lastError, 'error1');

      engine.config(onTaskError: (e, s) => lastError = 'new_$e');
      try {
        await engine.schedule(() => throw 'error2');
      } catch (_) {}
      expect(lastError, 'new_error2');
    });

    test('accepts null onTaskError to clear handler', () async {
      Object? lastError;
      engine.config(onTaskError: (e, s) => lastError = e);

      try {
        await engine.schedule(() => throw 'error_before_clear');
      } catch (_) {}
      expect(lastError, 'error_before_clear');

      lastError = null;
      engine.config(onTaskError: null);

      try {
        await engine.schedule(() => throw 'error_after_clear');
      } catch (_) {}
      expect(lastError, isNull);
    });

    test('updates cacheProvider', () async {
      final cache1 = MockCache();
      final cache2 = MockCache();

      final policy = TaskCachePolicy<int>(
        ttl: const Duration(minutes: 1),
        toJson: (v) => {'v': v},
        fromJson: (j) => j['v'] as int,
      );

      engine.config(cacheProvider: cache1);
      await engine.schedule(() => 42, id: 't1', cachePolicy: policy);
      expect(cache1.storage.containsKey('t1'), isTrue);
      expect(cache2.storage.containsKey('t1'), isFalse);

      engine.config(cacheProvider: cache2);
      await engine.schedule(() => 99, id: 't2', cachePolicy: policy);
      expect(cache2.storage.containsKey('t2'), isTrue);
    });

    test('private sentinel onTaskError unset is callable (coverage)', () {
      final classMirror = reflectClass(LevitTaskEngine);
      final lib = classMirror.owner as LibraryMirror;
      final symbol = MirrorSystem.getSymbol('_onTaskErrorUnset', lib);

      expect(
        () => classMirror.invoke(
          symbol,
          [StateError('noop'), StackTrace.current],
        ),
        returnsNormally,
      );
    });
  });
}
