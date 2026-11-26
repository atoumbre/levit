import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class _CheckoutController extends LevitController with LevitReactiveTasksMixin {
  Future<String> submit(
    Completer<String> gate, {
    LevitTaskConflictPolicy policy = LevitTaskConflictPolicy.reject,
  }) {
    return runTask<String>(
      (ctx) => Future.any<String>([
        gate.future,
        ctx.cancelled.then((_) {
          ctx.throwIfCancelled();
          return '';
        }),
      ]),
      id: 'checkout',
      conflictPolicy: policy,
      metadata: const LevitTaskMetadata(
        category: 'payments',
        blocksUserInteraction: true,
      ),
    );
  }
}

void main() {
  test(
    'default levit_dart barrel exposes task metadata and conflict exceptions',
    () async {
      final scope = LevitScope.root('default_barrel_tasks');
      final controller = scope.put(() => _CheckoutController());
      final gate = Completer<String>();

      final first = controller.submit(gate);
      expect(controller.hasBlockingTasks.value, isTrue);
      expect(controller.isBusyWhere(category: 'payments'), isTrue);

      expect(
        () => controller.submit(Completer<String>()),
        throwsA(isA<LevitTaskConflictException>()),
      );

      await expectLater(
        Future<String>.sync(
          () => controller.submit(
            Completer<String>(),
            policy: LevitTaskConflictPolicy.drop,
          ),
        ),
        throwsA(isA<LevitTaskDroppedException>()),
      );

      final secondGate = Completer<String>();
      final second = controller.submit(
        secondGate,
        policy: LevitTaskConflictPolicy.restart,
      );

      await expectLater(first, throwsA(isA<LevitTaskSupersededException>()));

      // Confirm queue-full exception type is directly referenceable as well.
      expect(LevitTaskQueueFullException, isNotNull);

      secondGate.complete('done');
      expect(await second, 'done');

      await scope.dispose();
    },
  );
}
