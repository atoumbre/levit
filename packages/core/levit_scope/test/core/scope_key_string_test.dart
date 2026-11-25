import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('registeredKeys uses debug string format with optional tag', () {
    final scope = LevitScope.root('key_format');
    scope.put<int>(() => 1);
    scope.put<int>(() => 2, tag: 't');
    expect(scope.registeredKeys, contains('int'));
    expect(scope.registeredKeys, contains('int_t'));
  });
}
