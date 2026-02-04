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

  test('bind(Stream) goes through middleware onSet', () async {
    final middleware = _SetCountMiddleware();
    Lx.addMiddleware(middleware);
    addTearDown(() => Lx.removeMiddleware(middleware));

    final controller = StreamController<int>.broadcast();
    addTearDown(() async => controller.close());

    final count = LxInt(0);
    count.bind(controller.stream);
    void noop() {}
    count.addListener(noop);

    controller.add(42);
    await Future<void>.delayed(Duration.zero);

    expect(count.value, 42);
    expect(middleware.setCount, greaterThan(0));
    count.removeListener(noop);
    count.close();
  });

  test('computed graphDepth follows dependency depth', () {
    final source = 0.lx;
    final level1 = LxComputed(() => source.value + 1);

    void noop1() {}
    level1.addListener(noop1);

    final level2 = LxComputed(() => level1.value + 1);
    void noop2() {}
    level2.addListener(noop2);

    expect(source.graphDepth, 0);
    expect(level1.graphDepth, 1);
    expect(level2.graphDepth, 2);

    level2.removeListener(noop2);
    level1.removeListener(noop1);
    level2.close();
    level1.close();
    source.close();
  });
}

class _SetCountMiddleware extends LevitReactiveMiddleware {
  int setCount = 0;

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          setCount++;
          next(value);
        };
      };
}
