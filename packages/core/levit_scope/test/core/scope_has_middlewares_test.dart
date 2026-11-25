import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('hasMiddlewares is false before middleware registration', () {
    expect(LevitScope.hasMiddlewares, isFalse);
  });
}
