import 'package:levit/levit.dart';
import 'package:test/test.dart';

class _TestController extends LevitController {}

void main() {
  test('levit kit re-exports core runtime APIs', () {
    final scope = Levit.createScope('app');
    addTearDown(scope.dispose);

    scope.run(() {
      final count = 0.lx;
      final doubled = LxComputed(() => count() * 2);
      final controller = Levit.put(() => _TestController());

      expect(Levit.find<_TestController>(), same(controller));
      expect(doubled(), 0);

      count(2);
      expect(doubled(), 4);

      doubled.close();
      count.close();
    });
  });
}
