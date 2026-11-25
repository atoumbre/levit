import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Reactive refresh notifications and stack traces', () {
    test('LxBase.refresh triggers middleware hooks', () {
      final val = 0.lx;
      bool beforeCalled = false;
      bool afterCalled = false;

      // Add dummy middleware
      final mw = Lx.addMiddleware(
        RefreshMiddleware(
          onBefore: (_) {
            beforeCalled = true;
            return true;
          },
          onAfter: (_) {
            afterCalled = true;
          },
        ),
      );

      addTearDown(() {
        Lx.removeMiddleware(mw);
      });

      // Call refresh (alias notify)
      val.refresh();

      expect(beforeCalled, isTrue, reason: 'onBeforeChange should be called');
      expect(afterCalled, isTrue, reason: 'onAfterChange should be called');
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
      final mw = Lx.addMiddleware(
        RefreshMiddleware(
          onBefore: (change) {
            if (change.stackTrace != null) seenStack = true;
            return true;
          },
        ),
      );
      addTearDown(() => Lx.removeMiddleware(mw));

      val.refresh();
      expect(seenStack, isTrue);
    });
  });
}

class RefreshMiddleware extends LevitReactiveMiddleware {
  final bool Function(LevitReactiveChange)? onBefore;
  final void Function(LevitReactiveChange)? onAfter;

  RefreshMiddleware({this.onBefore, this.onAfter});

  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
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
