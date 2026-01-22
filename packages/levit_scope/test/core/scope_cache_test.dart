import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('Levit Scope Cache Coverage', () {
    test('Correctly caches resolutions across deep nested scopes', () {
      final root = LevitScope.root();
      final parent = root.createScope('parent');
      final child = parent.createScope('child');

      // 1. Register in Root
      root.put<String>(() => 'ROOT_VAL', tag: 'A');

      // 2. Resolve in Parent (Populates Parent's cache pointing to Root)
      expect(parent.find<String>(tag: 'A'), 'ROOT_VAL');

      // 3. Resolve in Child (Should access Parent's cache)
      // This hits the logic where Child looks up Parent, finds it in Parent's cache,
      // and then caches Parent locally.
      expect(child.find<String>(tag: 'A'), 'ROOT_VAL');

      // Clean up
      root.reset(force: true);
    });
  });
}
