import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope Coverage', () {
    test('Cache Overwrite (Concurrent findAsync)', () async {
      // Goal: Trigger _resolutionCache coverage line 460
      // Logic: Concurrent findAsync calls should both resolve from parent
      // and attempt to update the cache in the child scope.

      final root = LevitScope.root();
      final child = root.createScope('child');

      // Register async dependency in root
      root.lazyPutAsync<String>(() async {
        await Future.delayed(Duration(milliseconds: 10)); // Force async gap
        return 'success';
      });

      // Launch two concurrent lookups from child
      // Both will miss local cache, go to parent, await, and then try to cache result.
      final future1 = child.findAsync<String>();
      final future2 = child.findAsync<String>();

      final results = await Future.wait([future1, future2]);

      expect(results[0], 'success');
      expect(results[1], 'success');

      // Cleanup
      root.dispose();
    });

    test('Cache Overflow (Logic > 500 items)', () {
      // Goal: Trigger _resolutionCache.clear() line 466

      final root = LevitScope.root();
      final child = root.createScope('child');

      // Register 505 items in root (using distinct tags)
      for (var i = 0; i < 505; i++) {
        root.put(() => i, tag: '$i');
      }

      // Find all items from child to populate resolution cache
      for (var i = 0; i < 505; i++) {
        final val = child.find<int>(tag: '$i');
        expect(val, i);
      }

      // Execution should complete without error
      // Internally, cache should have cleared around index 502

      root.dispose();
    });
  });
}
