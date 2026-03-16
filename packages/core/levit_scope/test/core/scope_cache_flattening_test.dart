import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Resolution cache flattening (4-level scope)', () {
    final root = LevitScope.root('root');
    final child1 = root.createScope('child1');
    final child2 = child1.createScope('child2');
    final child3 = child2.createScope('child3');

    root.put<int>(() => 42);

    expect(child1.find<int>(), 42);
    expect(child2.find<int>(), 42);
    expect(child3.find<int>(), 42);
  });
}
