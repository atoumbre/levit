import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

// Controller that uses the mixin but will be instantiated manually (no DI)
class OrphanController extends LevitController with LevitReactiveTasksMixin {}

void main() {
  test(
      'Manual controller instantiation should link reactive mixin fields via autoDispose',
      () {
    // 1. Manually instantiate controller (simulating nested or non-DI usage)
    final controller = Levit.put(() => OrphanController());

    // 2. Trigger onInit (which calls autoDispose on tasks, taskWeights, taskProgress)
    // controller.onInit();

    // 3. Verify that these fields have an ownerId set
    // Currently, without the fix, this should be null (FAIL).
    // After fix, it should be 'OrphanController' (runtimeType).

    print('Tasks ownerId: ${controller.tasks.ownerId}');

    expect(controller.tasks.ownerId, isNotNull,
        reason: 'Tasks map should have an ownerId');
    expect(controller.tasks.ownerId, contains('OrphanController'),
        reason: 'OwnerId should fallback to runtimeType');

    // Cleanup
    controller.onClose();
  });
}
