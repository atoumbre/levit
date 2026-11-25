import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

void main() {
  test('queued tasks respect priority order with maxConcurrent=1', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final order = <String>[];
    final blocker = Completer<void>();

    final f1 = engine.schedule((_) async {
      await blocker.future;
      order.add('first');
    }, priority: LevitTaskPriority.normal);

    final f2 = engine.schedule((_) async {
      order.add('high');
    }, priority: LevitTaskPriority.high);

    final f3 = engine.schedule((_) async {
      order.add('low');
    }, priority: LevitTaskPriority.low);

    blocker.complete();

    await Future.wait([f1, f2, f3]);

    expect(order, ['first', 'high', 'low']);
  });

  test('cancel() resolves queued future and triggers onCancel', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final blocker = Completer<void>();

    final activeFuture = engine.schedule((_) async {
      await blocker.future;
      return 'active';
    }, id: 'active');

    var cancelled = false;
    final queuedFuture = engine.schedule(
      (_) async => 'queued',
      id: 'queued',
      onCancel: () => cancelled = true,
    );

    await Future<void>.delayed(Duration.zero);
    engine.cancel('queued');

    await expectLater(
      queuedFuture,
      throwsA(isA<LevitTaskCancelledException>()),
    );
    expect(cancelled, isTrue);

    blocker.complete();
    expect(await activeFuture, isNotNull);
  });

  test('cancelAll() resolves queued futures and triggers onCancel', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final blocker = Completer<void>();
    final cancels = <String>[];

    final activeFuture = engine.schedule((_) async {
      await blocker.future;
      return 'active';
    }, id: 'active');

    final queued1 = engine.schedule(
      (_) async => 'q1',
      id: 'q1',
      onCancel: () => cancels.add('q1'),
    );
    final queued2 = engine.schedule(
      (_) async => 'q2',
      id: 'q2',
      onCancel: () => cancels.add('q2'),
    );

    await Future<void>.delayed(Duration.zero);
    engine.cancelAll();

    await expectLater(queued1, throwsA(isA<LevitTaskCancelledException>()));
    await expectLater(queued2, throwsA(isA<LevitTaskCancelledException>()));
    expect(cancels, containsAll(<String>['q1', 'q2']));

    blocker.complete();
    await expectLater(
      activeFuture,
      throwsA(isA<LevitTaskCancelledException>()),
    );
  });
}
