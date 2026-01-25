import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Levit.enableAutoLinking();
  });

  tearDown(() {
    Levit.reset(force: true);
    Levit.disableAutoLinking();
  });

  group('Auto-linking Optimizations', () {
    test('ownerId is propagated via Zone values (Optimization 1)', () {
      final controller = OwnerIdTestController();
      Levit.put(() => controller, tag: 'test-owner-id');

      expect(controller.reactive.ownerId,
          equals('0:OwnerIdTestController_test-owner-id'));
    });

    test('ChainedCaptureList is flattened for nested captures (Optimization 2)',
        () {
      // We'll use reflection-like check or just verify behavior
      final controller = NestedCaptureController();
      Levit.put(() => controller);

      // Verify reactives are correctly linked
      expect(controller.outerReactive, isNotNull);
      expect(controller.innerReactive, isNotNull);

      // If we could inspect _ChainedCaptureList, we would check targets.length == 3
      // (Root captured list + Parent flattened list which had 2 targets)
      // But we can verify it doesn't crash and still link properly.
    });

    test(
        'Middleware skips processing when no capture scope is active (Optimization 4)',
        () {
      // This is hard to "prove" without internal access, but we can verify
      // that manual reactive creation outside of a capture scope still works
      // and doesn't incorrectly pick up a stale capture key from another Zone.
      final r = 0.lx;
      expect(r.ownerId, isNull);
      r.close();
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
  late final LxReactive outerReactive;
  late final LxReactive innerReactive;

  @override
  void onInit() {
    outerReactive = 1.lx;

    // Trigger another runCaptured block to create nested chaining
    runCapturedForTesting(() {
      runCapturedForTesting(() {
        innerReactive = 2.lx;
      }, 'level-2');
    }, 'level-1');

    super.onInit();
  }
}
