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
  test('Middleware cancellation prevents updates', () {
    Lx.addMiddleware(TestRejectMiddleware());

    final count = 0.lx;
    count.value = 1;
    expect(count.value, equals(0));

    final name = 'a'.lxNullable;
    name.value = 'b';
    expect(name.value, equals('a'));

    expect(() => Lx.batch(() {}), throwsStateError);
    expect(() => Lx.batchAsync(() async {}), throwsStateError);
  });
}
