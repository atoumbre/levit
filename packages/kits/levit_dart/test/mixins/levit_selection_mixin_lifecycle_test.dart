import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestSelectionController extends LevitController
    with LevitSelectionMixin {}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });
  test('LevitSelectionMixin gaps', () {
    final controller = TestSelectionController();
    controller.didAttachToScope(Ls.currentScope, key: 'test');
    controller.onInit();
  });
}
