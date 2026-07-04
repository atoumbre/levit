import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override
  LxOnSet? get onSet => (next, reactive, change) => (value) {};
  @override
  LxOnBatch? get onBatch =>
      (next, change) => () => throw StateError('Batch rejected');
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];
  @override
  LxOnSet? get onSet => (next, reactive, change) => (value) {
        next(value);
        changes.add(change);
      };
}

void main() {
  test('LevitReactiveMiddleware default implementations', () {
    final simpleMiddleware = TestSimpleMiddleware();
    Lx.addMiddleware(simpleMiddleware);

    final count = 0.lx;
    count.value = 1;
    expect(count.value, equals(1));
    expect(simpleMiddleware.changes, hasLength(1));

    Lx.batch(() {
      count.value = 2;
    });
    expect(count.value, equals(2));
  });
}
