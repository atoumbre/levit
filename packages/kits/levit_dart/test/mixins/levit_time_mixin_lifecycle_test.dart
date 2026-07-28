import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestTimeController extends LevitController with LevitTimeMixin {}

void main() {
  test('LevitTimeMixin gaps', () async {
    await Levit.runInScope<void>(() {
      Levit.put(() => TestTimeController());
    }, name: 'time_mixin_test');
  });
}
