import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class TestController extends LevitController {}

void main() {
  group('Controller initialization and disposal', () {
    test('Properties reflect state', () async {
      final controller = TestController();

      expect(controller.isInitialized, false);
      expect(controller.isClosed, false);
      expect(controller.registrationKey, null);

      controller.onInit();
      expect(controller.isInitialized, true);

      await controller.onClose();
      expect(controller.isClosed, true);

      // Simulate scope attachment (normally done by DI)
      final scope = LevitScope.root();
      controller.didAttachToScope(scope, key: 'testKey');
      expect(controller.registrationKey, 'testKey');
    });
  });
}
