import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override LxOnSet? get onSet => (next, reactive, change) => (value) {};
  @override LxOnBatch? get onBatch => (next, change) => () => throw StateError('Batch rejected');
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];
  @override LxOnSet? get onSet => (next, reactive, change) => (value) { next(value); changes.add(change); };
}

void main() {
  test('LxWorker stream listener', () async {
    final rx = 0.lx;
    var count = 0;
    final watch = LxWorker(rx, (v) => count++);

    rx.value = 1;
    await Future.delayed(Duration.zero);
    expect(count, 1);

    watch.close();
  });
}
