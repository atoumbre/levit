import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController with LevitTasksMixin {}

void main() {
  test('task controllers initialize and dispose with their scope', () async {
    await Levit.runInScope<void>(() {
      Levit.put(() => TestController());
    }, name: 'task_lifecycle_test');
  });
}
