import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('hasMiddlewares getter coverage', () {
    expect(LevitScope.hasMiddlewares, isFalse);
  });
}
