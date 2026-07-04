import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Stress Test: Async Types', () {
    test('LxFuture Rapid Create - 1000 LxFuture instances', () async {
      print('[Description] Tests rapidly creating LxFuture instances.');
      const iterations = 1000;

      final sw = Stopwatch()..start();
      final futures = <LxFuture<int>>[];
      for (var i = 0; i < iterations; i++) {
        futures.add(LxFuture(Future.value(i)));
      }
      await Future.delayed(const Duration(milliseconds: 100));
      sw.stop();

      var successCount = 0;
      for (final f in futures) {
        if (f.status case LxSuccess()) {
          successCount++;
        }
        f.close();
      }

      print(
          'Created $iterations LxFuture instances in ${sw.elapsedMilliseconds}ms, $successCount resolved');
      expect(successCount, greaterThan(0));
    });

    test('LxStream High Throughput - 10k events', () async {
      print('[Description] Tests LxStream with a high-throughput stream.');
      const eventCount = 10000;
      final controller = StreamController<int>.broadcast();
      final lxStream = LxStream(controller.stream);

      var receivedCount = 0;
      lxStream.addListener(() => receivedCount++);

      final sw = Stopwatch()..start();
      for (var i = 0; i < eventCount; i++) {
        controller.add(i);
      }
      await Future.delayed(const Duration(milliseconds: 100));
      sw.stop();

      print(
          'Emitted $eventCount events in ${sw.elapsedMilliseconds}ms, received $receivedCount notifications');
      expect(receivedCount, greaterThan(0));

      await controller.close();
      lxStream.close();
    });

    test('LxStream Rapid Restart + Fan-out - 200 restarts', () async {
      print(
          '[Description] Tests rapid LxStream.restart calls with redundant restarts and fan-out listeners.');
      const restartCount = 200;
      const fanOutListeners = 4;

      final controllers = List.generate(
        restartCount + 1,
        (_) => StreamController<int>.broadcast(),
      );
      final lxStream = LxStream<int>(controllers.first.stream, initial: 0);

      final received = List<int>.filled(fanOutListeners, 0);
      final subscriptions = List.generate(
        fanOutListeners,
        (i) => lxStream.valueStream.listen((_) => received[i]++),
      );

      final sw = Stopwatch()..start();
      for (var i = 1; i <= restartCount; i++) {
        final next = controllers[i].stream;
        lxStream.restart(next);
        // Redundant restart to exercise short-circuit path.
        lxStream.restart(next);
        controllers[i].add(i);
        if (i % 20 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sw.stop();

      final minReceived = received.reduce(min);
      print(
          'Restarted $restartCount times in ${sw.elapsedMilliseconds}ms, per-listener counts: $received');

      expect(minReceived, greaterThan(0));
      expect(lxStream.lastValue, restartCount);

      for (final sub in subscriptions) {
        await sub.cancel();
      }
      for (final controller in controllers) {
        await controller.close();
      }
      lxStream.close();
    });

    test('LxAsyncComputed Rapid Invalidation - 500 invalidations', () async {
      print(
          '[Description] Tests LxAsyncComputed behavior under rapid invalidation.');
      final source = 0.lx;
      var computeCount = 0;

      final asyncComputed = LxAsyncComputed(() async {
        computeCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return source.value * 2;
      });
      final subscription = asyncComputed.stream.listen((_) {});

      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        source.value = i;
      }
      // Wait for final computation
      await Future.delayed(const Duration(milliseconds: 200));
      sw.stop();

      final status = asyncComputed.status;
      print(
          'Invalidated 500x in ${sw.elapsedMilliseconds}ms, compute called $computeCount times');
      print('Final status: $status');

      expect(status, isA<LxSuccess<int>>());
      expect(status.valueOrNull, 998);
      expect(computeCount, lessThan(500),
          reason: 'Should coalesce/debounce computations');

      await subscription.cancel();
      source.close();
      asyncComputed.close();
    });

    test('Async Race - 50 concurrent LxAsyncComputed on same source', () async {
      print(
          '[Description] Tests many async computeds racing on the same source.');
      final source = 0.lx;
      const computedCount = 50;

      final computeds = List.generate(computedCount, (i) {
        return LxAsyncComputed(() async {
          await Future.delayed(Duration(milliseconds: i % 10));
          return source.value + i;
        });
      });

      final subscriptions = [
        for (final computed in computeds) computed.stream.listen((_) {}),
      ];

      final sw = Stopwatch()..start();
      source.value = 100;
      await Future.delayed(const Duration(milliseconds: 200));
      sw.stop();

      var successCount = 0;
      for (final c in computeds) {
        if (c.status case LxSuccess()) {
          successCount++;
        }
      }

      print(
          '$computedCount async computeds, $successCount resolved in ${sw.elapsedMilliseconds}ms');

      expect(successCount, computedCount);

      source.close();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      for (final c in computeds) {
        c.close();
      }
    });
  });
}
