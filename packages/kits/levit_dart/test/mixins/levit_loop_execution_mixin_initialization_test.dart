import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestLoopController extends LevitController with LevitLoopExecutionMixin {}

void main() {
  test('LevitLoopExecutionMixin coverage', () async {
    await Levit.runInScope<void>(() {
      Levit.put(() => TestLoopController());
    }, name: 'loop_mixin_test');
  });
}
