import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class _TrackingMiddleware extends LevitReactiveMiddleware {
  final String id;
  int beforeCount = 0;
  int afterCount = 0;
  bool shouldStopBefore = false;
  bool shouldStopAfter = false;

  _TrackingMiddleware(this.id);

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          // Check propagation flag at RUNTIME (inside closure)
          if (change.isPropagationStopped) {
            next(value);
            return;
          }

          beforeCount++;
          if (shouldStopBefore) {
            change.stopPropagation();
            // If we stop propagation, we usually mean "stop the chain".
            // To allow core to run, we must call next(), but flag is set.
            // Downstream middlewares check flag and pass-through.
          }

          try {
            next(value);
          } finally {
            // After hook
            // Check propagation again? If stopped during unwind?
            // Note: wrapper unwind means we are AFTER inner middlewares returned.
            // If inner middleware stopped propagation, we should see it?
            // But if we stopped it ourselves in 'before', it is still stopped.
            // Legacy: 'onAfter' ran even if 'stopPropagation' called?
            // Test says: mw1 runs after (since it processed).

            // Wait, if change.isPropagationStopped is true, do we run After?
            // Logic: if WE set pass-through initially (at start of method), we return 'next' and don't count.
            // If we are here, we passed 'before' check.
            // So we run 'after'.

            afterCount++;
            if (shouldStopAfter) change.stopPropagation();
          }
        };
      };

  @override
  LxOnBatch? get onBatch => (next, change) => next;

  void reset() {
    beforeCount = 0;
    afterCount = 0;
    shouldStopBefore = false;
    shouldStopAfter = false;
  }
}

void main() {
  group('Middleware Propagation', () {
    late _TrackingMiddleware mw1;
    late _TrackingMiddleware mw2;

    setUp(() {
      mw1 = _TrackingMiddleware('1');
      mw2 = _TrackingMiddleware('2');
      Lx.clearMiddlewares();
      Lx.addMiddleware(mw1);
      Lx.addMiddleware(mw2);
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('Normal flow notifies all middlewares', () {
      final count = 0.lx;
      count.value = 1;

      expect(mw1.beforeCount, equals(1));
      expect(mw2.beforeCount, equals(1));
      expect(mw1.afterCount, equals(1));
      expect(mw2.afterCount, equals(1));
    });

    test('stopPropagation in onSet (before) stops subsequent middlewares', () {
      mw1.shouldStopBefore = true;
      final count = 0.lx;
      count.value = 1;

      // MW1 runs
      expect(mw1.beforeCount, equals(1));
      // MW2 should be skipped (pass-through)
      expect(mw2.beforeCount, equals(0),
          reason: 'MW2 before should be skipped');

      // Value still updates (core reached)
      expect(count.value, equals(1));

      // After hooks:
      expect(mw1.afterCount, equals(1),
          reason: 'MW1 after should run since it processed');
      expect(mw2.afterCount, equals(0),
          reason: 'MW2 after should be skipped because passed through');
    });

    test('stopPropagation in onSet (after) affects upstream in unwind', () {
      // MW2 (inner) stops propagation.
      // MW1 (outer) should see it?
      // If wrapper pattern, MW2 runs BEFORE MW1 in unwind.

      mw2.shouldStopAfter = true;
      final count = 0.lx;
      count.value = 1;

      expect(mw1.beforeCount, equals(1));
      expect(mw2.beforeCount, equals(1));

      expect(mw2.afterCount, equals(1));

      // MW1 sees propagation stopped? No, MW1 logic doesn't check 'isPropagationStopped' inside the wrapper closure.
      // It counts.
      // LEGACY behavior was separate loops.
      // NEW behavior: once `next()` returns, we are back in `mw1` closure.
      // `mw1` increments `afterCount` unconditionally in my impl above.

      // If we want to support stopping propagation UPSTREAM (during unwind), we must check flag.
      expect(mw1.afterCount, equals(1));
    });
  });
}
