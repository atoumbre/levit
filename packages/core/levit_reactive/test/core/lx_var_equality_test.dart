import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('equality checks', () {
    final count = 1.lx; final count2 = 1.lx;
    expect(count == count, isTrue);
    expect(count == count2, isFalse);
    expect(count.toString(), equals('1'));
  });
}
