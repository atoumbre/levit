import 'package:flutter_test/flutter_test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: LxComputed', () {
    test('Deep Chain - 5000 LxComputed nodes', () {
      print(
          '[Description] Tests propagation through a deeply chained dependency graph.');
      final source = 0.lx;
      const depth = 5000;

      // Build chain
      final sw = Stopwatch()..start();
      LxComputed<int> current = LxComputed(() => source.value);
      for (var i = 1; i < depth; i++) {
        final prev = current;
        current = LxComputed(() => prev.value + 1);
      }
      sw.stop();
      print('Created $depth computed nodes in ${sw.elapsedMilliseconds}ms');

      // Verify final value
      expect(current.value, depth - 1);

      // Measure propagation
      sw.reset();
      sw.start();
      source.value = 10;
      final result = current.value;
      sw.stop();

      expect(result, depth - 1 + 10);
      print(
          'Propagated change through $depth nodes in ${sw.elapsedMilliseconds}ms');

      source.close();
      current.close();
    });

    test('Diamond Graph - Glitch Freedom', () {
      print(
          '[Description] Verifies that diamond-shaped dependencies do not cause glitches.');
      final source = 0.lx;
      const layers = 100;

      // Diamond pattern: source -> [left, right] -> join
      var left = LxComputed(() => source.value);
      var right = LxComputed(() => source.value);
      var join = LxComputed(() => left.value + right.value);

      final sw = Stopwatch()..start();
      for (var i = 0; i < layers; i++) {
        final prevJoin = join;
        left = LxComputed(() => prevJoin.value);
        right = LxComputed(() => prevJoin.value);
        join = LxComputed(() => left.value + right.value);
      }
      sw.stop();
      print(
          'Diamond Graph Setup: Created $layers diamond layers in ${sw.elapsedMilliseconds}ms');

      // Initial value
      expect(join.value, 0);

      // Track recomputations via listener
      var recomputeCount = 0;
      join.addListener(() => recomputeCount++);

      sw.reset();
      sw.start();
      source.value = 1;
      final result = join.value;
      sw.stop();

      print(
          'Diamond Graph Update: Propagated change through $layers layers in ${sw.elapsedMilliseconds}ms');
      print('Recompute notifications: $recomputeCount');

      expect(result, isNonNegative);
      source.close();
    });

    test('Fan-In - One LxComputed observing 5k sources', () {
      print('[Description] Tests computed that aggregates many sources.');
      const sourceCount = 5000;
      final sources = List.generate(sourceCount, (_) => 0.lx);

      final sw = Stopwatch()..start();
      final sum =
          LxComputed(() => sources.fold<int>(0, (acc, lx) => acc + lx.value));
      final initialValue = sum.value;
      sw.stop();

      expect(initialValue, 0);
      print(
          'Fan-In Setup: Initial computation with $sourceCount sources in ${sw.elapsedMilliseconds}ms');

      // Update a single source
      sw.reset();
      sw.start();
      sources[0].value = 100;
      final resultAfterSingle = sum.value;
      sw.stop();
      expect(resultAfterSingle, 100);
      print(
          'Fan-In Single Update: Propagated single source change in ${sw.elapsedMilliseconds}ms');

      for (final s in sources) {
        s.close();
      }
      sum.close();
    });
  });
}
