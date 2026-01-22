import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Transactional Batching', () {
    test('Lx.batch groups multiple notifications into one', () {
      final a = 0.lx;
      final b = 0.lx;
      int aNotifyCount = 0;
      int bNotifyCount = 0;

      a.addListener(() => aNotifyCount++);
      b.addListener(() => bNotifyCount++);

      Lx.batch(() {
        a.value = 1;
        a.value = 2;
        b.value = 10;

        expect(aNotifyCount, 0, reason: 'Should not notify during batch');
        expect(bNotifyCount, 0, reason: 'Should not notify during batch');
      });

      expect(aNotifyCount, 1, reason: 'Should notify once after batch for a');
      expect(bNotifyCount, 1, reason: 'Should notify once after batch for b');
      expect(a.value, 2);
      expect(b.value, 10);
    });

    test('Lx.isBatching returns correct state', () {
      expect(Lx.isBatching, isFalse);
      Lx.batch(() {
        expect(Lx.isBatching, isTrue);
      });
      expect(Lx.isBatching, isFalse);
    });

    test('Nested batches are supported and notify once at the end', () {
      final a = 0.lx;
      int notifyCount = 0;
      a.addListener(() => notifyCount++);

      Lx.batch(() {
        a.value = 1;
        Lx.batch(() {
          a.value = 2;
        });
        expect(notifyCount, 0, reason: 'Should not notify during nested batch');
      });

      expect(notifyCount, 1,
          reason: 'Should notify exactly once after outer batch');
    });
    test('Deeply nested batches work and notify once at the outermost end', () {
      final a = 0.lx;
      int notifyCount = 0;
      a.addListener(() => notifyCount++);

      Lx.batch(() {
        a.value = 1;
        Lx.batch(() {
          a.value = 2;
          Lx.batch(() {
            a.value = 3;
            Lx.batch(() {
              a.value = 4;
            });
          });
        });
        expect(notifyCount, 0);
      });

      expect(notifyCount, 1);
      expect(a.value, 4);
    });

    test('Errors in batch still trigger notifications for successful updates',
        () {
      final a = 0.lx;
      int notifyCount = 0;
      a.addListener(() => notifyCount++);

      try {
        Lx.batch(() {
          a.value = 1;
          throw Exception('fail');
        });
      } catch (_) {}

      expect(a.value, 1);
      expect(notifyCount, 1, reason: 'Should notify even if batch errored');
    });

    test('Lx.batch returns value from callback', () {
      final a = 0.lx;
      final b = 0.lx;

      final result = Lx.batch(() {
        a.value = 10;
        b.value = 20;
        return a.value + b.value;
      });

      expect(result, 30);
      expect(a.value, 10);
      expect(b.value, 20);
    });

    test('Lx.batch can return any type', () {
      final name = ''.lx;

      final greeting = Lx.batch(() {
        name.value = 'Alice';
        return 'Hello, ${name.value}!';
      });

      expect(greeting, 'Hello, Alice!');

      // Test returning an object
      final data = Lx.batch(() {
        return {'name': name.value, 'count': 42};
      });

      expect(data, {'name': 'Alice', 'count': 42});
    });

    test('Lx.batch with void callback works correctly', () {
      final a = 0.lx;
      int notifyCount = 0;
      a.addListener(() => notifyCount++);

      // void callback still works
      Lx.batch(() {
        a.value = 5;
      });

      expect(a.value, 5);
      expect(notifyCount, 1);
    });
  });

  group('Batch with LxComputed', () {
    test('LxComputed recomputes after batch completes', () async {
      final a = 1.lx;
      final b = 2.lx;
      int computeCount = 0;

      final sum = LxComputed(() {
        computeCount++;
        return a.value + b.value;
      });

      // Initial computation
      expect(sum.value, 3);
      expect(computeCount, 2);

      // Batch update
      Lx.batch(() {
        a.value = 10;
        b.value = 20;
      });

      // Stream subscriptions in Dart are async, so we need to await microtask
      await Future.microtask(() {});

      // Access the computed value after batch
      expect(sum.value, 30);
      // Computed may recompute per stream event (implementation detail)
      expect(computeCount, greaterThan(1));

      sum.close();
    });

    test('LxComputed notifies after batch with multiple dependency changes',
        () async {
      final x = 0.lx;
      final y = 0.lx;

      final product = LxComputed(() => x.value * y.value);
      int notifyCount = 0;
      product.addListener(() => notifyCount++);
      await Future.microtask(() {}); // Wait for listener to activate

      // Initial access to set up dependency tracking
      expect(product.value, 0);

      Lx.batch(() {
        x.value = 5;
        y.value = 6;
        x.value = 7; // Multiple changes to same var
      });

      // Wait for stream events to propagate
      await Future.delayed(Duration(milliseconds: 10));

      expect(product.value, 42); // 7 * 6
      // Note: listener count depends on implementation (may be >1 due to stream events)
      expect(notifyCount, greaterThanOrEqualTo(1));

      product.close();
    });

    test('Chained LxComputed updates correctly after batch', () async {
      final base = 1.lx;
      final doubled = LxComputed(() => base.value * 2);
      final quadrupled = LxComputed(() => doubled.value * 2);

      // Initial access
      expect(doubled.value, 2);
      expect(quadrupled.value, 4);

      Lx.batch(() {
        base.value = 5;
        base.value = 10;
      });

      // Wait for stream events to propagate through the chain
      await Future.delayed(const Duration(milliseconds: 10));

      expect(doubled.value, 20);
      expect(quadrupled.value, 40);

      doubled.close();
      quadrupled.close();
    });
  });

  group('Batch async behavior (documentation test)', () {
    test(
        'Async code after await is NOT batched - demonstrates sync-only behavior',
        () async {
      final a = 0.lx;
      final b = 0.lx;
      int aNotifyCount = 0;
      int bNotifyCount = 0;

      a.addListener(() => aNotifyCount++);
      b.addListener(() => bNotifyCount++);

      // This demonstrates the anti-pattern mentioned in docs
      // The batch completes synchronously, so `b.value = 2` after await
      // is NOT batched
      Lx.batch(() async {
        a.value = 1; // This IS batched
        await Future.delayed(const Duration(milliseconds: 10));
        b.value = 2; // This is NOT batched - batch already completed!
      });

      // Immediately after Lx.batch returns (synchronously):
      // - `a` should have been updated and batch should have notified once
      expect(a.value, 1);
      expect(aNotifyCount, 1);

      // Wait for the async operation to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Now `b` has been updated OUTSIDE the batch
      expect(b.value, 2);
      expect(bNotifyCount, 1); // `b` notified independently, not batched
    });

    test('Synchronous batch completes before async callbacks', () async {
      final values = <String>[];
      final x = 'initial'.lx;

      x.addListener(() => values.add('listener: ${x.value}'));

      Lx.batch(() async {
        x.value = 'sync';
        values.add('batch: sync');

        // Schedule async work (will run after batch completes)
        Future.microtask(() {
          values.add('microtask');
        });
      });

      values.add('after batch');

      // At this point, batch has completed synchronously
      expect(values, ['batch: sync', 'listener: sync', 'after batch']);

      // Wait for microtask
      await Future.delayed(Duration.zero);
      expect(values.last, 'microtask');
    });
    test('Batch notifies multiple listeners in loop', () {
      final a = 0.lx;
      final b = 0.lx;

      // We want to ensure the loop in batch() that iterates over the unique notifiers
      // is covered. We use two different reactives to ensure the Set iteration happens.
      int notifyCount = 0;
      a.addListener(() => notifyCount++);
      b.addListener(() => notifyCount++);

      Lx.batch(() {
        a.value = 1;
        b.value = 2;
      });

      expect(notifyCount, 2);
    });
  });
}
