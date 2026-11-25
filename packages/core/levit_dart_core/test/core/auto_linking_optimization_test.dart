import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/spi.dart';

void main() {
  setUp(() {
    Levit.enableAutoLinking();
  });

  tearDown(() async {
    await Levit.reset(force: true);
    Levit.disableAutoLinking();
  });

  group('Auto-linking Optimizations', () {
    test('ownerId is propagated via Zone values (Optimization 1)', () {
      final controller = OwnerIdTestController();
      Levit.put(() => controller, tag: 'test-owner-id');

      expect(
        controller.reactive.ownerId,
        equals('0:OwnerIdTestController_test-owner-id'),
      );
    });

    test('nested capture retains the innermost owner ID', () async {
      final controller = Levit.put(NestedCaptureController.new);
      expect(controller.innerReactive.ownerId, 'level-2');
      await Levit.delete<NestedCaptureController>();
      expect(controller.outerReactive.isDisposed, isTrue);
      expect(controller.innerReactive.isDisposed, isFalse);
      await controller.innerReactive.close();
    });

    test(
      'Middleware skips processing when no capture scope is active (Optimization 4)',
      () async {
        // This is hard to "prove" without internal access, but we can verify
        // that manual reactive creation outside of a capture scope still works
        // and doesn't incorrectly pick up a stale capture key from another Zone.
        final r = 0.lx;
        expect(r.ownerId, isNull);
        await r.close();
      },
    );

    test('disableAutoLinking fully detaches auto-link middlewares', () async {
      LxReactive? linked;
      LevitAutoLinkSpi.runCaptured(() {
        linked = 0.lx;
      }, 'owner:on');
      expect(linked!.ownerId, 'owner:on');
      await linked!.close();

      Levit.disableAutoLinking();

      LxReactive? unlinked;
      LevitAutoLinkSpi.runCaptured(() {
        unlinked = 1.lx;
      }, 'owner:off');
      expect(unlinked!.ownerId, isNull);
      await unlinked!.close();

      Levit.enableAutoLinking();

      LxReactive? relinked;
      LevitAutoLinkSpi.runCaptured(() {
        relinked = 2.lx;
      }, 'owner:on:again');
      expect(relinked!.ownerId, 'owner:on:again');
      await relinked!.close();
    });
  });
}

class OwnerIdTestController extends LevitController {
  late final LxReactive reactive;

  @override
  void onInit() {
    // We use a custom key to trigger the Zone-based ownerId propagation
    // Usually this is done by runCaptured internally when called by LevitScope.
    // Here Levit.put will trigger onInit inside runCaptured.
    reactive = 0.lx;
    super.onInit();
  }

  // We override the registration key for the test
  @override
  String get registrationKey => 'test-owner-id';
}

class NestedCaptureController extends LevitController {
  late final LxInt outerReactive;
  late final LxInt innerReactive;

  @override
  void onInit() {
    outerReactive = 1.lx;

    LevitAutoLinkSpi.runCaptured(() {
      LevitAutoLinkSpi.runCaptured(() {
        innerReactive = 2.lx;
      }, 'level-2');
    }, 'level-1');

    super.onInit();
  }
}
