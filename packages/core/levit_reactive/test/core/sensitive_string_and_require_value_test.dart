import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test(
    'sensitive reactives redact toString across base and async types',
    () async {
      final secret = LxVar<String>('top-secret-token', isSensitive: true);
      expect(secret.toString(), '***');
      expect(secret.toString(), isNot(contains('top-secret-token')));

      final asyncComputed = LxAsyncComputed<String>(
        () async => 'computed-secret',
        initial: 'computed-secret',
      )..isSensitive = true;
      expect(asyncComputed.toString(), 'LxComputed.async(***)');

      final controller = StreamController<String>.broadcast();
      final lxStream = LxStream<String>(controller.stream)..isSensitive = true;
      expect(lxStream.toString(), 'LxStream(***)');

      final completer = Completer<String>();
      final lxFuture = LxFuture<String>(
        completer.future,
        previous: const LxSuccess<String>('retained-secret'),
      )..isSensitive = true;
      expect(lxFuture.toString(), 'LxFuture(***)');

      expect(
        () => lxFuture.requireValue,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            isNot(contains('retained-secret')),
          ),
        ),
      );

      completer.complete('done');
      await Future<void>.delayed(Duration.zero);
      await lxFuture.close();
      await lxStream.close();
      await controller.close();
      await asyncComputed.close();
      await secret.close();
    },
  );
}
