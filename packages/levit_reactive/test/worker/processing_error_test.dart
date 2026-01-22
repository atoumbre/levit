import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Watcher onProcessingError', () {
    test('catches sync errors via watch', () {
      final s = 0.lx;
      dynamic caughtError;

      LxWatch(s, (v) {
        if (v == 1) throw 'Sync Error';
      }, onProcessingError: (e, s) {
        caughtError = e;
      });

      s.value = 1;
      expect(caughtError, 'Sync Error');
    });

    test('rethrows sync errors if handler missing', () {
      final s = 0.lx;
      LxWatch(s, (v) => throw 'Fail');
      expect(() => s.value = 1, throwsA('Fail'));
    });

    test('catches async errors via watch', () async {
      final s = 0.lx;
      final completer = Completer<dynamic>();

      LxWatch(s, (v) async {
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

      LxWatch.isTrue(
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

      LxWatch.status<int>(
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
