import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('sync find() throws clear error on uninitialized async dependency', () {
    final scope = LevitScope.root();

    // Register async dependency
    scope.lazyPutAsync(() async => 'AsyncValue', tag: 'test');

    // Verify it is registered
    expect(scope.isRegisteredLocally<String>(tag: 'test'), isTrue);
    expect(scope.isInstantiated<String>(tag: 'test'), isFalse);

    // Try sync find immediately - should fail with our new error
    try {
      scope.find<String>(tag: 'test');
      fail('Should have thrown StateError');
    } catch (e) {
      expect(e, isA<StateError>());
      // The error message we added: '... Use findAsync() to initialize it.'
      expect(e.toString(), contains('Use findAsync()'));
    }
  });
}
