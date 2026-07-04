import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls.createScope returns a new scope', () {
    final scope = Ls.createScope('test_scope');
    expect(scope.name, 'test_scope');
    Ls.reset(force: true);
  });
}
