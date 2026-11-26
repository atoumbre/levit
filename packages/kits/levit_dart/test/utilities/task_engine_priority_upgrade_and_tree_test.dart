import 'dart:async';

import 'package:levit_dart/tasks.dart';
import 'package:test/test.dart';

void main() {
  group('Task priority promotion and taskTree pending counts', () {
    test(
      'taskTree reports queued pendingCount and coalesceLatest upgrades promoted head priority',
      () async {
        final engine = LevitTaskEngine(maxConcurrent: 1);
        final firstGate = Completer<void>();
        final blockerGate = Completer<void>();
        final order = <String>[];

        final first = engine.submit<void>((_) async {
          order.add('first');
          await firstGate.future;
        }, id: 'work');

        final blocker = engine.submit<void>(
          (_) async {
            order.add('blocker');
            await blockerGate.future;
          },
          id: 'blocker',
          priority: LevitTaskPriority.high,
        );

        final coalescedLow = engine.submit<void>(
          (_) async {
            order.add('low-body');
          },
          id: 'work',
          priority: LevitTaskPriority.low,
          conflictPolicy: LevitTaskConflictPolicy.coalesceLatest,
        );

        final snapshot = engine.taskTree.value;
        expect(snapshot.runningCount, 1);
        expect(snapshot.pendingCount, 2);

        // Complete `first`: `blocker` takes the single slot, and `coalescedLow`
        // is promoted to the queued head of `work` in the low-priority queue.
        firstGate.complete();
        await first.result;
        await Future<void>.delayed(Duration.zero);

        final otherNormal = engine.submit<void>(
          (_) async {
            order.add('normal');
          },
          id: 'other',
          priority: LevitTaskPriority.normal,
        );

        // Upgrade the promoted queued head from low to high via coalesceLatest.
        final coalescedHigh = engine.submit<void>(
          (_) async {
            order.add('high-body');
          },
          id: 'work',
          priority: LevitTaskPriority.high,
          conflictPolicy: LevitTaskConflictPolicy.coalesceLatest,
        );

        blockerGate.complete();
        await Future.wait([
          blocker.result,
          coalescedLow.result,
          coalescedHigh.result,
          otherNormal.result,
        ]);

        expect(order, containsAllInOrder(['first', 'blocker', 'high-body']));
        expect(order.indexOf('high-body'), lessThan(order.indexOf('normal')));
        await engine.dispose();
      },
    );
  });
}
