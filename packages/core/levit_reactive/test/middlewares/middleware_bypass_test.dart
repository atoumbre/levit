import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class TestTrackingMiddleware extends LevitReactiveMiddleware {
  int beforeCount = 0;
  int afterCount = 0;

  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
    return (value) {
      beforeCount++;
      try {
        next(value);
      } finally {
        afterCount++;
      }
    };
  };

  // Pass-through batch
  @override
  LevitReactiveOnBatch? get onBatch =>
      (next, change) => next;

  void reset() {
    beforeCount = 0;
    afterCount = 0;
  }
}

void main() {
  group('Middleware Bypass', () {
    late TestTrackingMiddleware tracker;

    setUp(() {
      tracker = TestTrackingMiddleware();
      Lx.clearMiddlewares();
      Lx.addMiddleware(tracker);
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('runWithoutMiddleware prevents middleware execution', () {
      final count = 0.lx;

      // Normal update
      count.value = 1;
      expect(tracker.beforeCount, equals(1));
      expect(tracker.afterCount, equals(1));
      expect(count.value, equals(1));

      // Bypassed update
      Lx.runWithoutMiddleware(() {
        count.value = 2;
      });

      expect(
        tracker.beforeCount,
        equals(1),
        reason: 'Should not increment beforeCount',
      );
      expect(
        tracker.afterCount,
        equals(1),
        reason: 'Should not increment afterCount',
      );
      expect(count.value, equals(2), reason: 'Value should still update');
    });

    test('bypassed update correctly notifies listeners', () {
      final count = 0.lx;
      int listenerCount = 0;
      count.addListener(() => listenerCount++);

      Lx.runWithoutMiddleware(() {
        count.value = 5;
      });

      expect(count.value, equals(5));
      expect(listenerCount, equals(1));
    });
  });
}
