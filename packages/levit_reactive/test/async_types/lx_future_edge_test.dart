import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxFuture Edge Cases', () {
    test('wait propagates error from LxError state', () async {
      final f = LxFuture<String>(Future.error('failure'));

      // Wait for it to complete
      try {
        await f.wait;
      } catch (_) {}

      expect(f.status, isA<LxError>());

      // Now access .wait
      // It should return a Future that completes with error
      expect(f.wait, throwsA('failure'));
    });

    test('wait throws StateError if idle and no value', () {
      final f = LxFuture<String>.idle();
      expect(() => f.wait, throwsStateError);
    });
  });
}
