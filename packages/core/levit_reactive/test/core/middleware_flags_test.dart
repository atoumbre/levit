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
  test('Lx.hasSetMiddlewares coverage', () {
    Lx.clearMiddlewares();
    expect(LevitReactiveMiddleware.hasSetMiddlewares, isFalse);
    Lx.addMiddleware(TestSimpleMiddleware());
    expect(LevitReactiveMiddleware.hasSetMiddlewares, isTrue);
  });
}
