import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('LevitScopeKey.toString uses debug string format', () {
    expect(LevitScopeKey.of<int>().toString(), contains('int'));
    expect(LevitScopeKey.of<int>(tag: 't').toString(), contains('_t'));
  });
}
