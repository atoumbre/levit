import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test(
    'previous nullable success differs from absent data in every status',
    () {
      const success = LxSuccess<String?>(null);
      expect(success.hasLastValue, isTrue);
      expect(LxWaiting<String?>.fromPrevious(success).hasLastValue, isTrue);
      expect(LxIdle<String?>.fromPrevious(success).hasLastValue, isTrue);
      expect(
        LxError<String?>.fromPrevious('offline', null, success).hasLastValue,
        isTrue,
      );
      expect(
        LxWaiting<String?>(),
        isNot(const LxWaiting<String?>.retained(null)),
      );
      expect(LxIdle<String?>(), isNot(const LxIdle<String?>.retained(null)));
      expect(
        LxError<String?>('x'),
        isNot(LxError<String?>.retained('x', null)),
      );
    },
  );
  test('future replacement and failure preserve a successful null', () async {
    final source = LxFuture<String?>(Future.value(null));
    await source.wait;
    final next = Completer<String?>();
    source.restart(next.future);
    expect(source.value.hasLastValue, isTrue);
    final observed = expectLater(source.wait, throwsStateError);
    next.completeError(StateError('offline'));
    await observed;
    expect(source.value, isA<LxError<String?>>());
    expect(source.value.hasLastValue, isTrue);
    await source.close();
  });
}
