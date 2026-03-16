import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';
import 'dart:async';

void main() {
  group('Race Condition Coverage', () {
    test('Simultaneous async lookups hit _pendingInit cache', () async {
      final scope = LevitScope.root('race_test');
      int buildCount = 0;

      scope.lazyPutAsync<String>(() async {
        buildCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'Ready';
      });

      // Launch two lookups effectively simultaneously
      final future1 = scope.findAsync<String>();
      final future2 = scope.findAsync<String>();

      final results = await Future.wait([future1, future2]);

      expect(results[0], 'Ready');
      expect(results[1], 'Ready');
      expect(buildCount, 1, reason: 'Builder should execute exactly once');

      // The second future should have been served from _pendingInit
      // This implicitly covers the line: return await _pendingInit[key] as S;
    });
  });
}
