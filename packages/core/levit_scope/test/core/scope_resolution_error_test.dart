import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('find and findAsync error paths', () {
    final scope = LevitScope.root('error_test');
    expect(() => scope.find<String>(), throwsException);
    expect(() => scope.findAsync<String>(), throwsA(isA<Exception>()));
  });
}
