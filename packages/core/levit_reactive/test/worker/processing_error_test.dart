import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Watcher onProcessingError', () {
    test('catches sync errors via watch', () {
      final s = 0.lx;
      dynamic caughtError;

      LxWorker(s, (v) {
        if (v == 1) throw 'Sync Error';
      }, onProcessingError: (e, s) {
        caughtError = e;
      });

      s.value = 1;
      expect(caughtError, 'Sync Error');
    });

    test('traps sync errors if handler missing (via global middleware)', () {
      final s = 0.lx;
      dynamic capturedError;

      // Register temporary middleware to trap the error
      final middleware = _ErrorTrapMiddleware((e) => capturedError = e);
      LevitReactiveMiddleware.add(middleware);
      addTearDown(() => LevitReactiveMiddleware.remove(middleware));

      LxWorker(s, (v) => throw 'Fail');

      // Should not throw, but be trapped
      expect(() => s.value = 1, returnsNormally);
      expect(capturedError, equals('Fail'));
    });

    test('catches async errors via watch', () async {
      final s = 0.lx;
      final completer = Completer<dynamic>();

      LxWorker(s, (v) async {
        await Future.delayed(Duration.zero);
        throw 'Async Error';
      }, onProcessingError: (e, s) {
        if (!completer.isCompleted) completer.complete(e);
      });

      s.value = 1;
      expect(await completer.future, 'Async Error');
    });

    test('catches sync errors via watchTrue', () {
      final s = false.lx;
      dynamic caughtError;

      LxWorker.watchTrue(
        s,
        () => throw 'True Error',
        onProcessingError: (e, s) => caughtError = e,
      );

      s.setTrue();
      expect(caughtError, 'True Error');
    });

    test('catches async errors via watchStatus', () async {
      final s = LxVar<LxStatus<int>>(LxWaiting());
      final completer = Completer<dynamic>();

      LxWorker.watchStatus<int>(
        s,
        onSuccess: (v) async {
          throw 'Success Async Error';
        },
        onProcessingError: (e, s) {
          completer.complete(e);
        },
      );

      s.value = LxSuccess(10);
      expect(await completer.future, 'Success Async Error');
    });
  });
}

class _ErrorTrapMiddleware extends LevitReactiveMiddleware {
  final void Function(Object) onError;
  _ErrorTrapMiddleware(this.onError);

  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError =>
      (e, s, c) => onError(e);
}
