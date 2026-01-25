import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxMap.remove reproduction', () {
    final map = <int, String>{}.lx;
    map[1] = 'one';
    expect(map.containsKey(1), isTrue);
    final removed = map.remove(1);
    expect(removed, 'one');
    expect(map.containsKey(1), isFalse);
  });
}
