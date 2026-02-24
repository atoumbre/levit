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

      count.divide(5); // 12 ~/ 5 = 2
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

      price.add(1.5);
      expect(price.value, 4.0);

      price.subtract(1.0);
      expect(price.value, 3.0);

      price.multiply(2.5);
      expect(price.value, 7.5);

      price.mod(2.0);
      expect(price.value, 1.5);

      price.negate();
      expect(price.value, -1.5);

      price.clampValue(0.0, 10.0);
      expect(price.value, 0.0);
    });

    test('LxInt divide throws on division by zero', () {
      final count = 1.lx;
      expect(
        () => count.divide(0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
