import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test('Cache Overwrite (Concurrent findAsync)', () async {
    final root = LevitScope.root();
    final child = root.createScope('child');
    root.lazyPutAsync<String>(() async { await Future.delayed(Duration(milliseconds: 10)); return 'success'; });
    final future1 = child.findAsync<String>();
    final future2 = child.findAsync<String>();
    final results = await Future.wait([future1, future2]);
    expect(results[0], 'success'); expect(results[1], 'success');
  });
}
