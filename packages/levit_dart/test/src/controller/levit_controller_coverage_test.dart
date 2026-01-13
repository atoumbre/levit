import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController {}

void main() {
  group('LevitController Coverage', () {
    test('Properties reflect state', () {
      final controller = TestController();

      expect(controller.isInitialized, false);
      expect(controller.isClosed, false);
      expect(controller.registrationKey, null);

      controller.onInit();
      expect(controller.isInitialized, true);

      controller.onClose();
      expect(controller.isClosed, true);

      // Simulate scope attachment (normally done by DI)
      final scope = LevitScope.root();
      controller.didAttachToScope(scope, key: 'testKey');
      expect(controller.registrationKey, 'testKey');
    });
  });
}
