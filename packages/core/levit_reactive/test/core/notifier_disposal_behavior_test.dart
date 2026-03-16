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
  test('LevitReactiveNotifier ignores operations after disposal', () {
    final notifier = LevitReactiveNotifier();
    var called = false;
    notifier.addListener(() => called = true);

    notifier.dispose();
    expect(notifier.isDisposed, isTrue);

    notifier.notify();
    expect(called, isFalse);

    notifier.addListener(() => called = true);
  });
}
