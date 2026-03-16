import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Collections Coverage', () {
    test('LxList forEach', () {
      final list = [1, 2, 3].lx;
      int sum = 0;
      list.forEach((e) => sum += e);
      expect(sum, 6);
    });

    test('LxSet forEach', () {
      final set = {1, 2, 3}.lx;
      int sum = 0;
      set.forEach((e) => sum += e);
      expect(sum, 6);
    });
  });
}
