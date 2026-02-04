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
}
