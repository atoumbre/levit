import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls.createScope returns a new scope', () async {
    final scope = Ls.createScope('test_scope');
    expect(scope.name, 'test_scope');
    await Ls.reset(force: true);
  });
}
