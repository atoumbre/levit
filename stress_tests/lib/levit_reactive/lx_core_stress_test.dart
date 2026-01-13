import 'package:flutter_test/flutter_test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Lx Core', () {
    test('Bulk Update - 100k rapid updates to a single Lx', () {
      print(
          '[Description] Measures throughput of rapid value updates on a single Lx<int>.');
      final count = 0.lx;
      const iterations = 100000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        count.value = i;
      }
      sw.stop();

      final opsPerMs = iterations / sw.elapsedMilliseconds;
      print(
          'Performed $iterations updates in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(0)} ops/ms)');

      count.close();
    });

    test('Listener Fan-Out - 10k listeners on a single Lx', () {
      print('[Description] Tests notification broadcast to 10,000 listeners.');
      final source = 0.lx;
      const listenerCount = 10000;
      var callCount = 0;

      for (var i = 0; i < listenerCount; i++) {
        source.addListener(() => callCount++);
      }

      final sw = Stopwatch()..start();
      source.value = 1;
      sw.stop();

      expect(callCount, listenerCount);
      print('Notified $listenerCount listeners in ${sw.elapsedMilliseconds}ms');

      source.close();
    });

    test('Listener Add/Remove Churn - 5k add/remove cycles', () {
      print(
          '[Description] Tests efficiency of listener management under churn.');
      final source = 0.lx;
      const cycles = 5000;

      void listener() {}

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        source.addListener(listener);
        source.removeListener(listener);
      }
      sw.stop();

      final opsPerMs = (cycles * 2) / sw.elapsedMilliseconds;
      print(
          'Performed ${cycles * 2} add/remove ops in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(0)} ops/ms)');

      source.close();
    });
  });
}
