import 'package:flutter_test/flutter_test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Watchers (LxWatch)', () {
    test('LxWatch Subscribe/Unsubscribe Churn - 10k cycles', () {
      print(
          '[Description] Tests efficiency of creating and disposing LxWatch subscriptions.');
      final source = 0.lx;
      const cycles = 10000;

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        final watcher = LxWatch(source, (_) {});
        watcher.close();
      }
      sw.stop();

      final opsPerMs = cycles / sw.elapsedMilliseconds;
      print(
          'Performed $cycles LxWatch create/dispose cycles in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(0)} ops/ms)');

      source.close();
    });

    test('LxWatch Callback Flood - 100k rapid updates', () async {
      print(
          '[Description] Tests LxWatch callback performance under flood conditions.');
      final source = 0.lx;
      const updates = 100000;

      var callbackCount = 0;
      final watcher = LxWatch(source, (_) => callbackCount++);

      final sw = Stopwatch()..start();
      for (var i = 0; i < updates; i++) {
        source.value = i;
      }
      sw.stop();

      print('Flooded $updates updates in ${sw.elapsedMilliseconds}ms');
      print('Callback invocations: $callbackCount');

      expect(callbackCount, updates);

      watcher.close();
      source.close();
    });

    test('LxWatch.isTrue and LxWatch.isFalse - Toggle stress', () async {
      print('[Description] Tests boolean watchers under rapid toggling.');
      final flag = false.lx;
      const toggles = 10000;

      var trueCount = 0;
      var falseCount = 0;

      final trueWatcher = LxWatch.isTrue(flag, () => trueCount++);
      final falseWatcher = LxWatch.isFalse(flag, () => falseCount++);

      final sw = Stopwatch()..start();
      for (var i = 0; i < toggles; i++) {
        flag.value = !flag.value;
      }
      sw.stop();

      print('Toggled $toggles times in ${sw.elapsedMilliseconds}ms');
      print(
          'LxWatch.isTrue fired: $trueCount, LxWatch.isFalse fired: $falseCount');

      expect(trueCount, toggles ~/ 2);
      expect(falseCount, toggles ~/ 2);

      trueWatcher.close();
      falseWatcher.close();
      flag.close();
    });
  });
}
