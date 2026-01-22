import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('Levit DI Coverage Boost', () {
    test('Resolution cache flattening (4-level scope)', () {
      final root = LevitScope.root('root');
      final child1 = root.createScope('child1');
      final child2 = child1.createScope('child2');
      final child3 = child2.createScope('child3');

      root.put<int>(() => 42);

      // 1. Resolve in Child1. Child1's cache points to Root.
      expect(child1.find<int>(), 42);

      // 2. Resolve in Child2. Child2's cache points to Root (hits line 362 via Child1).
      expect(child2.find<int>(), 42);

      // 3. Resolve in Child3. Child3's cache points to Root (hits line 362 via Child2).
      expect(child3.find<int>(), 42);
    });

    test('find and findAsync error paths', () {
      final scope = LevitScope.root('error_test');

      expect(() => scope.find<String>(), throwsException);
      expect(() => scope.findAsync<String>(), throwsA(isA<Exception>()));
    });
  });
}
