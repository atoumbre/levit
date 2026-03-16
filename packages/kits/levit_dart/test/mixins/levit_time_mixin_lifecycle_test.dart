import 'package:levit_dart/levit_dart.dart'; import 'package:test/test.dart';
class TestTimeController extends LevitController with LevitTimeMixin {}
void main() { setUp(() { Levit.reset(force: true); });
  test('LevitTimeMixin gaps', () { final controller = TestTimeController(); controller.didAttachToScope(Ls.currentScope, key: 'test'); controller.onInit(); });
}