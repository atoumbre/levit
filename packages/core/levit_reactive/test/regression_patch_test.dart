import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxComputed init failure does not corrupt dependency tracking', () {
    final a = LxVar(1);
    try {
      LxComputed(() {
        a.value;
        throw StateError('boom');
      });
    } catch (_) {}

    final b = LxVar(1);
    final computed = LxComputed(() => b.value + 1, eager: true);
    int notifyCount = 0;
    computed.addListener(() => notifyCount++);

    b.value = 2;
    expect(computed.value, 3);
    expect(notifyCount, 1);
  });

  test('LxFuture does not emit after close', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final completer = Completer<int>();
      final lx = LxFuture<int>(completer.future);
      lx.close();
      completer.complete(1);
      await Future<void>.delayed(Duration.zero);
    }, (e, st) {
      errors.add(e);
    });

    expect(errors, isEmpty);
  });

  test('LxAsyncComputed does not emit after close', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final completer = Completer<int>();
      final computed = LxComputed.async<int>(() => completer.future);
      computed.addListener(() {});
      computed.close();
      completer.complete(1);
      await Future<void>.delayed(Duration.zero);
    }, (e, st) {
      errors.add(e);
    });

    expect(errors, isEmpty);
  });
}
