import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Function Extensions', () {
    test('.lx creates LxComputed from sync function', () {
      final count = 1.lx;
      final doubled = (() => count.value * 2).lx;

      expect(doubled, isA<LxComputed<int>>());
      expect(doubled.value, equals(2));

      count.value = 5;
      expect(doubled.value, equals(10));
    });

    test('.lx creates LxAsyncComputed from async function', () async {
      final count = 1.lx;
      final delayedDoubled = (() async {
        await Future.delayed(Duration(milliseconds: 10));
        return count.value * 2;
      }).lx;

      expect(delayedDoubled, isA<LxAsyncComputed<int>>());

      // Add listener to activate the lazy computed
      delayedDoubled.addListener(() {});

      expect(delayedDoubled.status, isA<LxWaiting<int>>());

      await Future.delayed(Duration(milliseconds: 200));
      expect(delayedDoubled.status, isA<LxSuccess<int>>());
      expect(delayedDoubled.status.valueOrNull, equals(2));

      count.value = 5;
      await Future.delayed(Duration(milliseconds: 200)); // Allow async update
      expect(delayedDoubled.status.valueOrNull, equals(10));
    });
  });
}
