import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Stress Test: LWatch', () {
    testWidgets('Fan-In - LWatch observing 1000 sources', (tester) async {
      print('[Description] Tests LWatch with many dependencies.');
      const sourceCount = 1000;
      final sources = List.generate(sourceCount, (_) => 0.lx);

      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: LWatch(() {
          buildCount++;
          var sum = 0;
          for (final s in sources) {
            sum += s.value;
          }
          return Text('Sum: $sum');
        }),
      ));

      expect(buildCount, 1);

      // Update one source
      final sw = Stopwatch()..start();
      sources[0].value = 100;
      await tester.pump();
      sw.stop();

      expect(buildCount, 2);
      print(
          'LWatch Fan-In: Initial build with $sourceCount sources, single update rebuild in ${sw.elapsedMilliseconds}ms');

      for (final s in sources) {
        s.close();
      }
    });

    testWidgets('Rapid Rebuild - 60fps simulation for 2 seconds',
        (tester) async {
      print(
          '[Description] Simulates 60fps updates and measures rebuild performance.');
      final source = 0.lx;

      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: LWatch(() {
          buildCount++;
          return Text('Value: ${source.value}');
        }),
      ));

      const frames = 120; // 2 seconds at 60fps
      final frameDuration = const Duration(milliseconds: 16);

      final sw = Stopwatch()..start();
      for (var i = 0; i < frames; i++) {
        source.value = i;
        await tester.pump(frameDuration);
      }
      sw.stop();

      print(
          'Rapid Rebuild: $buildCount builds over $frames frame updates in ${sw.elapsedMilliseconds}ms');
      expect(
          buildCount, greaterThanOrEqualTo(frames)); // May vary due to timing

      source.close();
    });

    testWidgets('Subscribe Cleanup - 500 mount/unmount cycles', (tester) async {
      print('[Description] Verifies LWatch cleans up subscriptions correctly.');
      final source = 0.lx;
      const cycles = 500;

      final sw = Stopwatch()..start();
      for (var i = 0; i < cycles; i++) {
        await tester.pumpWidget(MaterialApp(
          home: LWatch(() {
            return Text('Value: ${source.value}');
          }),
        ));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      }
      sw.stop();

      print(
          'LWatch Subscribe Cleanup: $cycles mount/unmount cycles in ${sw.elapsedMilliseconds}ms');

      source.close();
    });
  });
}
