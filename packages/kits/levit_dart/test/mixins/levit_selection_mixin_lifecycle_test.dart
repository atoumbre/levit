import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestSelectionController extends LevitController
    with LevitSelectionMixin {}

void main() {
  test(
    'selection controllers initialize and dispose with their scope',
    () async {
      await Levit.runInScope<void>(() {
        Levit.put(() => TestSelectionController());
      }, name: 'selection_mixin_test');
    },
  );
}
