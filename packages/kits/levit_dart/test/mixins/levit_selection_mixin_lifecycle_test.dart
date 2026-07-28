import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestSelectionController extends LevitController
    with LevitSelectionMixin {}

void main() {
  test('LevitSelectionMixin gaps', () async {
    await Levit.runInScope<void>(() {
      Levit.put(() => TestSelectionController());
    }, name: 'selection_mixin_test');
  });
}
