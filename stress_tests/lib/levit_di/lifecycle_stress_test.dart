import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart/levit_dart.dart';

class _DisposableService implements LevitScopeDisposable {
  static int initCount = 0;
  static int disposeCount = 0;

  @override
  void onInit() {
    initCount++;
  }

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}

  @override
  void onClose() {
    disposeCount++;
  }
}

void main() {
  setUp(() {
    Levit.reset(force: true);
    _DisposableService.initCount = 0;
    _DisposableService.disposeCount = 0;
  });

  group('Stress Test: DI Lifecycle', () {
    test('Disposable Cleanup - 10k services', () {
      print(
          '[Description] Verifies onClose is called for all disposable services.');
      const count = 10000;

      for (var i = 0; i < count; i++) {
        Levit.put<_DisposableService>(() => _DisposableService(),
            tag: 'svc_$i');
      }

      expect(_DisposableService.initCount, count);

      final sw = Stopwatch()..start();
      Levit.reset(force: true);
      sw.stop();

      expect(_DisposableService.disposeCount, count);
      print(
          'Disposed $count services in ${sw.elapsedMilliseconds}ms (onClose count: ${_DisposableService.disposeCount})');
    });

    test('Concurrent Find - 10k concurrent futures', () async {
      print('[Description] Tests concurrent resolution safety.');
      const count = 10000;

      Levit.put<_DisposableService>(() => _DisposableService(), tag: 'shared');

      final sw = Stopwatch()..start();
      final futures = List.generate(
          count,
          (_) => Future.microtask(() {
                return Levit.find<_DisposableService>(tag: 'shared');
              }));
      final results = await Future.wait(futures);
      sw.stop();

      expect(results.length, count);
      expect(results, everyElement(isA<_DisposableService>()));
      print(
          'Resolved $count concurrent requests in ${sw.elapsedMilliseconds}ms');

      Levit.reset(force: true);
    });

    test('Put/Delete Cycles - 100k iterations', () {
      print('[Description] Tests rapid put/delete lifecycle churn.');
      const cycles = 100000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        Levit.put<_DisposableService>(() => _DisposableService(), tag: 'churn');
        Levit.delete<_DisposableService>(tag: 'churn', force: true);
      }
      sw.stop();

      expect(_DisposableService.initCount, cycles);
      expect(_DisposableService.disposeCount, cycles);
      print(
          'Performed $cycles put/delete cycles in ${sw.elapsedMilliseconds}ms');
    });
  });
}
