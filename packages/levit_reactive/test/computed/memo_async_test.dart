import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxComputed.async (memoized by default)', () {
    test('computes initial value correctly', () async {
      final c = LxComputed.async(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(c.status, isA<LxWaiting<int>>());

      // Activate
      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));

      expect(c.computedValue, 42);
      expect(c.isSuccess, true);
    });

    test('recomputes when dependency changes', () async {
      final source = 10.lx;
      final c = LxComputed.async(() async {
        final val = source.value; // Tracking BEFORE await
        await Future.delayed(Duration(milliseconds: 10));
        return val * 2;
      });

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 20);

      source.value = 20;
      // Should NOT transition to waiting (memoAsync behavior)
      expect(c.isSuccess, true);
      expect(c.computedValue, 20); // Stale value

      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 40);
    });

    test('does not notify if resolved value is equal', () async {
      final source = 10.lx;
      var computeCount = 0;
      var notifyCount = 0;

      final c = LxComputed.async<int>(() async {
        final val = source.value; // Tracking BEFORE await
        computeCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return val % 2; // Always 0 for even, 1 for odd
      });

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(computeCount, 1);

      // Attach listener AFTER initial success to avoid capture of Waiting -> Success
      c.addListener(() => notifyCount++);
      final initialNotifies = notifyCount;

      // Change source but keep result same
      source.value = 12; // 12 % 2 is still 0
      await Future.delayed(Duration(milliseconds: 50));

      expect(computeCount, 2);
      expect(notifyCount, initialNotifies); // NO new notification
    });

    test('uses custom equality check', () async {
      final source = 'hello'.lx;
      final c = LxComputed.async(
        () async {
          final val = source.value;
          await Future.delayed(Duration(milliseconds: 10));
          return val.length;
        },
        equals: (a, b) => a == b, // length equality
      );

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 5);

      source.value = 'world'; // Same length
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 5);

      source.value = 'hi'; // Different length
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 2);
    });

    test('transitions to waiting only on initial run', () async {
      final source = 0.lx;
      final c = LxComputed.async(() async {
        final val = source.value;
        await Future.delayed(Duration(milliseconds: 10));
        return val;
      });

      expect(c.isWaiting, true); // Initial

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.isSuccess, true);

      source.value = 1;
      expect(c.isWaiting, false); // Should NOT show waiting for recompute

      await Future.delayed(Duration(milliseconds: 50));
      expect(c.isSuccess, true);
    });

    test('handles errors correctly', () async {
      final shouldFail = false.lx;
      final c = LxComputed.async<int>(() async {
        final fail = shouldFail.value;
        await Future.delayed(Duration(milliseconds: 10));
        if (fail) throw 'async fail';
        return 42;
      });

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 42);

      shouldFail.value = true;
      await Future.delayed(Duration(milliseconds: 50));

      expect(c.isError, true);
      expect(c.errorOrNull, 'async fail');
      expect(c.lastValue, 42); // Preserves last success
    });

    test(
        'clears waiting status even if value is equal when showWaiting is true',
        () async {
      final source = 0.lx;
      final c = LxComputed.async(
        () async {
          final val = source.value;
          await Future.delayed(Duration(milliseconds: 10));
          return 42 + (val * 0); // Constant result but uses val
        },
        showWaiting: true,
      );

      c.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(c.computedValue, 42);

      source.value = 1;
      expect(c.isWaiting, true); // showWaiting is true

      await Future.delayed(Duration(milliseconds: 50));
      expect(c.isSuccess, true); // Should return to success
      expect(c.computedValue, 42);
    });

    test('toString returns correct type', () {
      final c = LxComputed.async(() async => 1);
      expect(c.toString(), contains('LxComputed.async'));
    });
  });
}
