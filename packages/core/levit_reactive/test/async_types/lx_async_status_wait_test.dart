import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxStatusReactiveExtensions', () {
    test(
        'wait handles consecutive LxWaiting states without throwing StateError',
        () async {
      LxStatus<int> initial = LxWaiting<int>();
      final reactive = initial.lx;

      // Start waiting
      final future = reactive.wait;

      // Emit another waiting (e.g., refresh called)
      reactive.value = LxWaiting<int>();

      // Yield to let the event loop process the await stream.firstWhere
      await Future.delayed(Duration.zero);

      // Emit success
      reactive.value = LxSuccess<int>(42);

      final res = await future;
      expect(res, equals(42));
    });

    test('wait immediately returns value if state is already LxSuccess',
        () async {
      LxStatus<int> initial = LxSuccess<int>(99);
      final reactive = initial.lx;

      final res = await reactive.wait;
      expect(res, equals(99));
    });

    test('wait immediately throws if state is already LxError', () async {
      LxStatus<int> initial = LxError<int>(Exception('Immediate failure'));
      final reactive = initial.lx;

      expect(
        () => reactive.wait,
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('Immediate failure'))),
      );
    });

    test('wait throws when stream closes before reaching terminal state',
        () async {
      LxStatus<int> initial = LxWaiting<int>();
      final reactive = initial.lx;

      final future = reactive.wait;

      // Close the reactive stream before emitting success or error
      reactive.close();

      expect(
        () => future,
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('stream closed unexpectedly'))),
      );
    });
  });
}
