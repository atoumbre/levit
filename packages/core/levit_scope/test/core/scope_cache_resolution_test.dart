import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('findOrNull and findAsync hit resolution cache', () async {
    final parent = LevitScope.root('parent');
    final child = parent.createScope('child');
    parent.put(() => 'parent_val');
    parent.lazyPutAsync(() async => 'parent_async_val');

    expect(child.findOrNull<String>(), 'parent_val');
    await child.findAsync<String>();

    expect(child.findOrNull<String>(), 'parent_val');
    expect(await child.findAsync<String>(), 'parent_val');
    expect(await child.findOrNullAsync<String>(), 'parent_val');
  });
}
