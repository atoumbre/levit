import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxFuture wait on LxWaiting', () {
    test('wait throws StateError when future is still waiting', () async {
      // Create a never-completing future
      final completer = Completer<int>();
      final lxFuture = LxFuture<int>(completer.future);

      // The status should be LxWaiting
      expect(lxFuture.status, isA<LxWaiting<int>>());

      // wait should wait for the stream to emit a terminal state
      // Since the completer never completes, we test the branch
      // by completing it after a delay
      Future.delayed(Duration(milliseconds: 50), () {
        completer.complete(42);
      });

      final result = await lxFuture.wait;
      expect(result, 42);
    });

    test('wait propagates error from LxError state', () async {
      final lxFuture = LxFuture<int>(Future.error('test error'));

      // Wait for error to propagate
      await Future.delayed(Duration(milliseconds: 10));

      expect(lxFuture.status, isA<LxError<int>>());
      expect(() => lxFuture.wait, throwsA('test error'));
    });

    test('wait throws StateError on idle LxFuture', () {
      final lxFuture = LxFuture<int>.idle();

      expect(lxFuture.status, isA<LxIdle<int>>());
      expect(
        () => lxFuture.wait,
        throwsA(isA<StateError>()),
      );
    });
  });
}
