import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  group('Lx.batchAsync', () {
    test('suppresses notifications during async gaps', () async {
      final a = 0.lx;
      final b = 0.lx;
      int notifications = 0;

      // Listen to both
      a.addListener(() => notifications++);
      b.addListener(() => notifications++);

      await Lx.batchAsync(() async {
        a.value = 1;
        // Should be 0 here as we utilize Zone batching
        expect(notifications, 0, reason: 'Should not notify immediately');

        await Future.delayed(Duration.zero);

        b.value = 1;
        expect(notifications, 0, reason: 'Should not notify after async gap');
      });

      // Should happen after batch completes
      expect(notifications, 2, reason: 'Should flush all notifications');
    });

    test('flushes notifications even on error', () async {
      final a = 0.lx;
      int notifications = 0;
      a.addListener(() => notifications++);

      try {
        await Lx.batchAsync(() async {
          a.value = 1;
          await Future.delayed(Duration.zero);
          throw Exception('Test Error');
        });
      } catch (_) {
        // Expected
      }

      expect(notifications, 1,
          reason: 'Should flush notifications in finally block');
      expect(a.value, 1);
    });

    test('supports nested sync transactions', () async {
      final a = 0.lx;
      final b = 0.lx;
      int aNotifications = 0;
      int bNotifications = 0;
      a.addListener(() => aNotifications++);
      b.addListener(() => bNotifications++);

      await Lx.batchAsync(() async {
        a.value = 1;

        Lx.batch(() {
          b.value = 1;
          b.value = 2; // Should only notify once for 'b'
        });

        // Lx.batch (sync) uses the GLOBAL batch state, which currently pushes to _batchedNotifiers.
        // However, our LevitReactiveNotifier.notify checks 'asyncBatch' (Zone) FIRST.
        // So even inside Lx.batch(), the Zone check wins if we prioritize it.
        //
        // Let's verify existing behavior:
        // LevitReactiveNotifier.notify implementation puts Zone check (0) BEFORE Sync check (1).
        // So 'b' updates inside sync batch will ACTUALLY be captured by the ASYNC batch
        // because the Zone is still active!
        // This effectively "promotes" the sync batch content to the surrounding async batch.

        expect(aNotifications, 0);
        expect(bNotifications, 0,
            reason: 'Sync batch should merge into async batch context');
      });

      expect(aNotifications, 1);
      expect(bNotifications,
          1); // Only 1 notification for b (last valid value, deduped)
    });
    test('triggers middleware hooks', () async {
      int startCount = 0;
      int endCount = 0;

      final middleware = TestBatchHookMiddleware(
        onStart: () => startCount++,
        onEnd: () => endCount++,
      );

      Lx.addMiddleware(middleware);

      try {
        await Lx.batchAsync(() async {
          expect(startCount, 1,
              reason: 'onBatchStart should be called before execution');
          expect(endCount, 0,
              reason: 'onBatchEnd should NOT be called during execution');
          await Future.delayed(Duration.zero);
        });

        expect(startCount, 1);
        expect(endCount, 1,
            reason: 'onBatchEnd should be called after execution');
      } finally {
        Lx.removeMiddleware(middleware);
      }
    });

    test('flushes batched notifiers after async batch completes', () async {
      final source1 = 0.lx;
      final source2 = 1.lx;
      var notifyCount1 = 0;
      var notifyCount2 = 0;

      source1.addListener(() => notifyCount1++);
      source2.addListener(() => notifyCount2++);

      await Lx.batchAsync(() async {
        source1.value = 10;
        await Future.delayed(Duration(milliseconds: 10));
        source2.value = 20;

        // Notifications should be batched
        expect(notifyCount1, 0);
        expect(notifyCount2, 0);
      });

      // After batch completes, notifiers should be flushed
      expect(notifyCount1, 1);
      expect(notifyCount2, 1);
      expect(source1.value, 10);
      expect(source2.value, 20);
    });
  });
}

class TestBatchHookMiddleware extends LevitReactiveMiddleware {
  final void Function() onStart;
  final void Function() onEnd;

  TestBatchHookMiddleware({required this.onStart, required this.onEnd});

  @override
  LxOnBatch? get onBatch => (next, change) {
        return () {
          onStart();
          // ignore: prefer_typing_uninitialized_variables
          var result;
          try {
            result = next();
          } catch (e) {
            onEnd();
            rethrow;
          }

          if (result is Future) {
            return result.whenComplete(onEnd);
          } else {
            onEnd();
            return result;
          }
        };
      };
}
