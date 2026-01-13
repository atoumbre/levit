import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStatus/LxFuture', () {
    test('LxFuture.idle starts with idle status', () {
      final future = LxFuture<int>.idle(initial: 0);
      expect(future.valueOrNull, equals(0));
    });
  });
}
