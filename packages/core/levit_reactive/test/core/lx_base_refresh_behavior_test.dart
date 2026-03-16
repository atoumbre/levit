import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Coverage Gaps', () {
    test('LxBase.refresh triggers middleware hooks', () {
      final val = 0.lx;
      bool beforeCalled = false;
      bool afterCalled = false;

      // Add dummy middleware
      final mw = Lx.addMiddleware(CoverageGapMiddleware(
        onBefore: (_) {
          beforeCalled = true;
          return true;
        },
        onAfter: (_) {
          afterCalled = true;
        },
      ));

      addTearDown(() {
        Lx.removeMiddleware(mw);
      });

      // Call refresh (alias notify)
      val.refresh();

      expect(beforeCalled, isTrue, reason: 'onBeforeChange should be called');
      expect(afterCalled, isTrue, reason: 'onAfterChange should be called');
    });

    test('LxBase.refresh restore callback is covered by HistoryMiddleware undo',
        () async {
      final val = 0.lx;

      // Use History Middleware
      final history = LevitReactiveHistoryMiddleware();
      final mw = Lx.addMiddleware(history);

      addTearDown(() {
        Lx.removeMiddleware(mw);
      });

      // Change value (Mutation 1)
      val.value = 1;

      // Refresh (Mutation 2 - same value but recorded as change)
      val.refresh();

      expect(val.value, 1);
      expect(history.length, 2);

      // Undo refresh (should restore to previous state of that mutation, which was 1)
      // refresh() change has oldValue=1, newValue=1.
      // restore(1) will be called.
      history.undo();

      expect(val.value, 1); // Value matches

      // Verify via side effect?
      // The restore callback calls _controller.add and notifier.notify.
      // We rely on stream emitting an event. Since controller is broadcast (async),
      // we must use expectLater.

      final emission = expectLater(val.stream, emits(anything));

      history.redo(); // Redo the refresh (calls restore with newValue)

      await emission;
    });

    test('LxBase.refresh captures stack trace when enabled', () {
      final val = 0.lx;

      final oldFlag = Lx.captureStackTrace;
      Lx.captureStackTrace = true;
      addTearDown(() => Lx.captureStackTrace = oldFlag);

      // Refresh to trigger stack capture
      val.refresh();

      // We can't easily verify the stack trace inside the change without middleware intercepting it.
      // But executing the line is enough for coverage.
      // Let's use a middleware to inspect it for correctness too.

      bool seenStack = false;
      final mw = Lx.addMiddleware(CoverageGapMiddleware(onBefore: (change) {
        if (change.stackTrace != null) seenStack = true;
        return true;
      }));
      addTearDown(() => Lx.removeMiddleware(mw));

      val.refresh();
      expect(seenStack, isTrue);
    });
  });
}

class CoverageGapMiddleware extends LevitReactiveMiddleware {
  final bool Function(LevitReactiveChange)? onBefore;
  final void Function(LevitReactiveChange)? onAfter;

  CoverageGapMiddleware({this.onBefore, this.onAfter});

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          if (onBefore != null) {
            final proceed = onBefore!(change);
            if (!proceed) {
              return; // Simulate rejection if needed (not used in test)
            }
          }
          next(value);
          onAfter?.call(change);
        };
      };
}
