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
  test('Lx convenience methods', () {
    final count = 0.lx;
    expect(count(), equals(0));
    expect(count(5), equals(5));
    expect(count.value, equals(5));

    count.updateValue((v) => v * 2);
    expect(count.value, equals(10));

    var notifications = 0;
    count.addListener(() => notifications++);

    count.refresh();
    expect(notifications, equals(1));

    final list = <int>[].lx;
    list.addListener(() => notifications++);
    list.mutate((l) => l.add(1));
    expect(notifications, equals(2));
    expect(list.value, equals([1]));
  });
}
