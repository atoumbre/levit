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
  test('LevitReactiveNotifier removeListener', () {
    final notifier = LevitReactiveNotifier();
    var count = 0;
    void listener() => count++;

    notifier.addListener(listener);
    notifier.notify();
    expect(count, 1);

    notifier.removeListener(listener);
    notifier.notify();
    expect(count, 1);
  });
}
