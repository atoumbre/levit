import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxWatch', () {
    test('tracks synchronous execution', () async {
      final count = 0.lx;
      final watcher = LxWatch(count, (_) {});

      expect(watcher.value.runCount, 0);

      count.value++;

      // Wait for propagation (sync usually immediate but let's be safe)
      await Future.delayed(Duration.zero);

      expect(watcher.value.runCount, 1);
      expect(watcher.value.lastDuration, isNotNull);
      expect(watcher.value.isAsync, isFalse);
      expect(watcher.value.isProcessing, isFalse);
      expect(watcher.value.error, isNull);

      watcher.close(); // Dispose
    });

    test('tracks asynchronous execution', () async {
      final count = 0.lx;
      final completer = Completer<void>();

      final watcher = LxWatch(count, (_) async {
        await completer.future;
      });

      expect(watcher.value.runCount, 0);

      count.value++;
      await Future.delayed(Duration.zero);

      // Should be processing
      expect(watcher.value.isProcessing, isTrue);
      expect(watcher.value.isAsync, isTrue);
      expect(
          watcher.value.runCount, 0); // Still running? or counts on completion?
      // Implementation increments AFTER completion.

      completer.complete();
      await Future.delayed(Duration.zero);

      expect(watcher.value.isProcessing, isFalse);
      expect(watcher.value.runCount, 1);
      expect(watcher.value.lastDuration >= Duration.zero, isTrue);

      watcher.close();
    });

    test('LxWatch implements close', () {
      final count = 0.lx;
      final watcher = LxWatch(count, (_) {});

      watcher.close();
      expect(watcher.isDisposed, isTrue);

      // Verify subscription is cancelled
      count.value = 1;

      // Stats should not update if disposed/cancelled properly
      // (This assumes listener removal works)
    });

    test('captures processing errors', () async {
      final count = 0.lx;
      final watcher = LxWatch(count, (_) {
        throw 'oops';
      }, onProcessingError: (e, s) {
        // Suppress rethrow for test
      });

      count.value++;
      await Future.delayed(Duration.zero);

      expect(watcher.value.runCount, 1);
      expect(watcher.value.error, 'oops');

      watcher.close();
    });

    test('captures async processing errors', () async {
      final count = 0.lx;
      final completer = Completer<void>();

      final watcher = LxWatch(count, (_) async {
        await completer.future;
        throw 'async oops';
      });

      count.value++;
      await Future.delayed(Duration.zero);
      expect(watcher.value.isProcessing, isTrue);

      completer.complete();
      await Future.delayed(Duration.zero);

      expect(watcher.value.isProcessing, isFalse);
      expect(watcher.value.runCount, 1);
      expect(watcher.value.error, 'async oops');

      watcher.close();
    });

    test('dispose stops tracking', () async {
      final count = 0.lx;
      final watcher = LxWatch(count, (_) {});

      count.value++;
      await Future.delayed(Duration.zero);
      expect(watcher.value.runCount, 1);

      watcher.close(); // Explicit call to test disposal

      count.value++;
      await Future.delayed(Duration.zero);
      expect(watcher.value.runCount, 1); // Should not increment
    });
  });
}
