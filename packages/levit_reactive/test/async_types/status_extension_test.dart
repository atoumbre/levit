import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStatusReactiveExtensions', () {
    test('works on raw LxVar<LxStatus<T>>', () {
      final statusLx = LxVar<LxStatus<int>>(LxIdle());

      // Initial state (Idle)
      expect(statusLx.isIdle, isTrue);
      expect(statusLx.isLoading, isFalse);
      expect(statusLx.hasValue, isFalse);
      expect(statusLx.isError, isFalse);
      expect(statusLx.valueOrNull, isNull);
      expect(statusLx.errorOrNull, isNull);

      // Transition to Waiting
      statusLx.value = LxWaiting();
      expect(statusLx.isIdle, isFalse);
      expect(statusLx.isLoading, isTrue);
      expect(statusLx.isWaiting, isTrue);

      // Transition to Success
      statusLx.value = const LxSuccess(42);
      expect(statusLx.isLoading, isFalse);
      expect(statusLx.hasValue, isTrue);
      expect(statusLx.isSuccess, isTrue);
      expect(statusLx.valueOrNull, 42);
      expect(statusLx.lastValue, 42);

      // Transition to Error
      final error = Exception('oops');
      statusLx.value = LxError(error, StackTrace.empty, 42);
      expect(statusLx.hasValue, isFalse);
      expect(statusLx.isError, isTrue);
      expect(statusLx.errorOrNull, error);
      expect(statusLx.valueOrNull, isNull);
      expect(statusLx.lastValue, 42); // lastValue persists
    });

    test('works on LxFuture (via inheritance)', () async {
      final completer = Completer<String>();
      final futureLx = LxFuture(completer.future);

      expect(futureLx.isWaiting, isTrue);

      completer.complete('done');
      await Future.delayed(Duration.zero); // Cycle event loop

      expect(futureLx.isSuccess, isTrue);
      expect(futureLx.valueOrNull, 'done');
    });
  });
}
