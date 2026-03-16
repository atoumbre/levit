import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_dart/levit_dart.dart';

void main() {
  test('queued tasks respect priority order with maxConcurrent=1', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final order = <String>[];
    final blocker = Completer<void>();

    final f1 = engine.schedule(() async {
      await blocker.future;
      order.add('first');
    }, priority: TaskPriority.normal);

    final f2 = engine.schedule(() async {
      order.add('high');
    }, priority: TaskPriority.high);

    final f3 = engine.schedule(() async {
      order.add('low');
    }, priority: TaskPriority.low);

    blocker.complete();

    await Future.wait([f1, f2, f3]);

    expect(order, ['first', 'high', 'low']);
  });

  test('cancel() resolves queued future and triggers onCancel', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final blocker = Completer<void>();

    final activeFuture = engine.schedule(() async {
      await blocker.future;
      return 'active';
    }, id: 'active');

    var cancelled = false;
    final queuedFuture = engine.schedule(() async => 'queued',
        id: 'queued', onCancel: () => cancelled = true);

    await Future<void>.delayed(Duration.zero);
    engine.cancel('queued');

    expect(await queuedFuture, isNull);
    expect(cancelled, isTrue);

    blocker.complete();
    expect(await activeFuture, isNotNull);
  });

  test('cancelAll() resolves queued futures and triggers onCancel', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final blocker = Completer<void>();
    final cancels = <String>[];

    final activeFuture = engine.schedule(() async {
      await blocker.future;
      return 'active';
    }, id: 'active');

    final queued1 = engine.schedule(
      () async => 'q1',
      id: 'q1',
      onCancel: () => cancels.add('q1'),
    );
    final queued2 = engine.schedule(
      () async => 'q2',
      id: 'q2',
      onCancel: () => cancels.add('q2'),
    );

    await Future<void>.delayed(Duration.zero);
    engine.cancelAll();

    expect(await queued1, isNull);
    expect(await queued2, isNull);
    expect(cancels, containsAll(<String>['q1', 'q2']));

    blocker.complete();
    expect(await activeFuture, isNull);
  });
}
