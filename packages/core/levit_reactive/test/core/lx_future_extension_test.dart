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
  test('Future.lx extension creates LxFuture', () async {
    final future = Future.value(42);
    final lxFuture = future.lx;

    expect(lxFuture, isA<LxFuture<int>>());

    await Future.delayed(Duration(milliseconds: 10));
    expect(lxFuture.status, isA<LxSuccess<int>>());
    expect(lxFuture.valueOrNull, equals(42));
  });
}
