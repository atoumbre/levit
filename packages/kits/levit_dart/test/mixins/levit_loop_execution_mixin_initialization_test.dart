import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestLoopController extends LevitController with LevitLoopMixin {}

void main() {
  test('loop controllers initialize and dispose with their scope', () async {
    await Levit.runInScope<void>(() {
      Levit.put(() => TestLoopController());
    }, name: 'loop_mixin_test');
  });
}
