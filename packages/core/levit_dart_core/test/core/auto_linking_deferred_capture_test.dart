import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_reactive/spi.dart';
import 'package:test/test.dart';

class _DeferredCaptureController extends LevitController {
  late LxVar<int> sideReactive;
  late LxVar<int> ownedResult;

  @override
  void onInit() {
    super.onInit();
    ownedResult = LxSpi.createOwned(() {
      sideReactive = 1.lx;
      return 2.lx;
    });
  }
}

void main() {
  test(
    'auto-linking captures non-returned reactives created inside createOwned',
    () async {
      Levit.enableAutoLinking();
      final scope = Levit.createScope('deferred_capture');
      final controller = scope.put(() => _DeferredCaptureController());

      expect(controller.sideReactive.isDisposed, isFalse);
      expect(controller.ownedResult.isDisposed, isFalse);

      await scope.dispose();

      expect(controller.sideReactive.isDisposed, isTrue);
      expect(controller.ownedResult.isDisposed, isFalse);

      await controller.ownedResult.close();
    },
  );
}
