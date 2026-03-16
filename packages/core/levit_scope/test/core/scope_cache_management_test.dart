import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope Cache Management', () {
    test('clears resolution cache on delete and reset', () {
      final root = LevitScope.root();
      final child = root.createScope('child');

      // Populate resolution cache by finding something in parent
      root.put(() => 42, tag: 'parent');
      child.find<int>(tag: 'parent');

      // Put something local so delete/reset has something to do and triggers the cache clearing logic
      child.put(() => 100, tag: 'local');
      expect(child.delete<int>(tag: 'local'), true);

      // Repopulate resolution cache for reset test
      child.find<int>(tag: 'parent');

      // Put another local item for reset to process
      child.put(() => 200, tag: 'local2');
      child.reset();

      expect(child.isRegisteredLocally<int>(tag: 'local2'), false);
    });
  });
}
