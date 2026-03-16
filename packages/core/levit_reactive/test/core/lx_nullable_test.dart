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
  test('LxNullable setNull', () {
    final name = 'test'.lxNullable;
    expect(name.value, equals('test'));
    name.value = null;
    expect(name.value, isNull);
  });
}
