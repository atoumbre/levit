import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxFuture wait works', () async {
    final waiting = LxFuture<int>(Future.value(1));
    expect(await waiting.wait, 1);

    final error = LxFuture<int>(Future.error('err'));
    expect(() => error.wait, throwsA('err'));
  });
}
