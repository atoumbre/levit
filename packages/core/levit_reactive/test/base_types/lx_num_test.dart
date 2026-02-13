import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxNum operations', () {
    test('LxInt operations', () {
      final count = 0.lx;

      count.increment();
      expect(count.value, 1);

      count.decrement();
      expect(count.value, 0);

      count.add(5);
      expect(count.value, 5);

      count.subtract(2);
      expect(count.value, 3);

      count.multiply(4);
      expect(count.value, 12);

      count.intDivide(5);
      expect(count.value, 2);

      count.mod(3);
      expect(count.value, 2);

      count.clampValue(0, 1);
      expect(count.value, 1);

      count.negate();
      expect(count.value, -1);
    });

    test('LxDouble operations', () {
      final price = 10.0.lx;

      price.divide(4);
      expect(price.value, 2.5);
    });

    test('LxInt divide throws on non-integer result', () {
      final count = 1.lx;
      expect(
        () => count.divide(2),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Use intDivide()'),
          ),
        ),
      );
    });

    test('LxInt divide allows exact integer result', () {
      final count = 8.lx;
      count.divide(2);
      expect(count.value, 4);
    });
  });
}
