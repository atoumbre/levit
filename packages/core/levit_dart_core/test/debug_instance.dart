import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  test('debug instance registration', () {
    final state = LevitState((ref) => 'test');
    final scope = LevitScope.root();
    state.findIn(scope, tag: 'my-tag');

    print('Registered keys: ${scope.registeredKeys}');

    final tag = getProviderTag(state, 'my-tag');
    final key = 'ls_value_$tag';
    print('Looking for key: $key');

    final instance = scope.findOrNull<dynamic>(tag: key);
    expect(instance, isNotNull);
  });
}
