import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController with LevitTasksMixin {}

void main() {
  test('LevitTasksMixin engine.config on double init', () async {
    await Levit.runInScope<void>(() {
      final controller = Levit.put(() => TestController());
      controller.onInit();
    }, name: 'task_config_test');
  });
}
