import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ErrorMiddleware extends LevitReactiveMiddleware {
  Object? lastError;
  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
      get onReactiveError => (e, s, c) => lastError = e;
}

void main() {
  group('levit_reactive Final Gaps', () {
    tearDown(() {
      LevitReactiveMiddleware.clear();
    });

    test('core.dart:478, 480-481 - Single listener error via batch', () {
      final middleware = ErrorMiddleware();
      LevitReactiveMiddleware.add(middleware);

      final rx = 0.lx;
      rx.addListener(() {
        throw 'SingleListenerError';
      });

      // Force use of _notifyListeners instead of the fast path in notify()
      // by running inside a batch (or by ensuring _fastPath is false)
      Lx.batch(() {
        rx.value = 1;
      });

      expect(middleware.lastError, 'SingleListenerError');
    });

    test('computed.dart:250 - LxComputed staticDeps (Active)', () {
      final a = 1.lx;
      final b = 2.lx;

      // Line 250 is hit during _recompute if _staticDeps is true AND _isActive is true
      final c = LxComputed(() => a.value + b.value, staticDeps: true);
      c.addListener(() {}); // Make it active

      expect(c.value, 3);
      a.value = 10;
      expect(c.value, 12);
    });

    test(
        'computed.dart:456 - LxAsyncComputed staticDeps sync error on first run (Active)',
        () async {
      final a = 1.lx;

      // Line 456 is hit in _run if _staticDeps is true and sync error occurs
      final c = LxAsyncComputed<int>(() async {
        if (a.value == 1) {
          // We need it to be truly synchronous throw during the setup of the future?
          // No, sync throw is caught in _run.
          throw 'SyncError';
        }
        return a.value;
      }, staticDeps: true);

      // Trigger first run by adding a listener (makes it active)
      c.addListener(() {});

      // Since it's async computation but sync throw in the closure,
      // it might depend on how the zone handles it.
      // But _run catches errors from runZoned.

      await Future.delayed(Duration(milliseconds: 10));

      expect(c.value, isA<LxError>());

      // Now change a.value
      a.value = 10;
      await Future.delayed(Duration(milliseconds: 10));
    });

    test('Additional edge case for static graph failure', () {
      // Just to be sure we hit the sync error path in static async
      try {
        final c = LxAsyncComputed<int>(() {
          throw 'ImmediateSyncError';
        }, staticDeps: true);
        c.addListener(() {});
      } catch (_) {}
    });
  });
}
