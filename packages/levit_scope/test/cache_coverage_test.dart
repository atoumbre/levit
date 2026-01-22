import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('LevitScope Cache Coverage', () {
    test('findOrNull and findAsync hit resolution cache', () async {
      final parent = LevitScope.root('parent');
      final child = parent.createScope('child');

      parent.put(() => 'parent_val');
      parent.lazyPutAsync(() async => 'parent_async_val');

      // 1. Initial resolution (populates cache)
      expect(child.findOrNull<String>(), 'parent_val');
      await child.findAsync<String>(); // Populates findAsync specific paths

      // 2. Second resolution (hits cache - line 324, 358)
      expect(child.findOrNull<String>(), 'parent_val');
      expect(await child.findAsync<String>(), 'parent_val');

      // hit findOrNullAsync cache (line 391)
      expect(await child.findOrNullAsync<String>(), 'parent_val');
    });

    test('hasMiddlewares getter coverage', () {
      expect(LevitScope.hasMiddlewares, isFalse);
    });
  });
}
