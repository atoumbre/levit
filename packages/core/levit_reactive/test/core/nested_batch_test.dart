import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  group('Nested Batch Composability', () {
    test('Lx.batchAsync inside Lx.batchAsync (deduplicates updates)', () async {
      final a = 0.lx;
      int count = 0;
      a.addListener(() => count++);

      await Lx.batchAsync(() async {
        a.value = 1;
        await Lx.batchAsync(() async {
          a.value = 2;
          await Future.delayed(Duration.zero);
        });
      });

      // Should only notify once with final value
      expect(count, 1);
      expect(a.value, 2);
    });

    test('Lx.batch inside Lx.batchAsync (merges into async batch)', () async {
      final a = 0.lx;
      int count = 0;
      a.addListener(() => count++);

      await Lx.batchAsync(() async {
        Lx.batch(() {
          a.value = 1;
        });
        await Future.delayed(Duration.zero);
        // Still in async batch, should not have notified yet
        expect(count, 0);
      });

      expect(count, 1);
    });

    test(
      'Lx.batchAsync inside Lx.batch (flushes global batch on completion)',
      () async {
        final a = 0.lx; // Updated in sync batch
        final b = 0.lx; // Updated in async batch
        int aCount = 0;
        int bCount = 0;
        a.addListener(() => aCount++);
        b.addListener(() => bCount++);

        final future = Lx.batch(() {
          a.value = 1;
          // Return the future so we can await it outside
          return Lx.batchAsync(() async {
            await Future.delayed(Duration.zero);
            b.value = 1;
          });
        });

        expect(
          aCount,
          1,
          reason: 'The synchronous batch ends before the await',
        );
        expect(bCount, 0);

        await future;
        // Async completion flushes only its own pending source.

        expect(bCount, 1, reason: 'Async batch should flush its own set');
        expect(
          aCount,
          1,
          reason: 'Async completion must not re-notify the synchronous source',
        );
      },
    );
  });
}
