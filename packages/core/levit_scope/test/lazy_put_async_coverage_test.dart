import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test('lazyPutAsync coverage for already instantiated dependency', () async {
    final scope = LevitScope.root();

    // 1. Register and instantiate
    scope.lazyPutAsync(() async => 'v1', tag: 't');
    await scope.findAsync<String>(tag: 't');

    // 2. lazyPutAsync again for same type/tag hits early return
    final builder = scope.lazyPutAsync(() async => 'v2', tag: 't');

    final result = await builder();
    expect(result, 'v1');
  });
}
