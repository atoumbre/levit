import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Deep Reactivity Repro', () {
    test('nested collections are NOT automatically wrapped', () {
      final list = [
        {'a': 1}
      ].lx;
      // Current behavior: it is just a plain Map
      expect(list[0], isA<Map>());
      expect(list[0], isNot(isA<LxMap>()));
    });

    test(
        'Deep mutation of plain nested object does not trigger top-level observer',
        () {
      final map = {
        'user': {'name': 'John'}
      }.lx;

      var count = 0;
      LxComputed<void>(() {
        // Read to track
        // accessing map['user'] tracks 'user' key.
        map['user'];
        count++;
      });

      expect(count, 1);

      // Mutate deep value which is currently just a plain Map
      (map['user'] as Map)['name'] = 'Jane';

      // Current behavior: no trigger
      expect(count, 1);
    });
  });
}
