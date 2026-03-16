import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test('Cache Overflow (Logic > 500 items)', () {
    final root = LevitScope.root();
    final child = root.createScope('child');
    for (var i = 0; i < 505; i++) { root.put(() => i, tag: '$i'); }
    for (var i = 0; i < 505; i++) { expect(child.find<int>(tag: '$i'), i); }
  });
}
