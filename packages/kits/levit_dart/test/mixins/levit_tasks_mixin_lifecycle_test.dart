import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController with LevitTasksMixin {}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });
  test('LevitTasksMixin onInit coverage', () {
    final controller = TestController();
    controller.didAttachToScope(Ls.currentScope, key: 'test');
    controller.onInit();
  });
}
