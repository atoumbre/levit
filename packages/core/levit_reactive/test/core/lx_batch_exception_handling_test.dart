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
  test('Lx.runBatch resets isBatching on exception', () {
    expect(Lx.isBatching, isFalse);
    try {
      Lx.batch(() {
        expect(Lx.isBatching, isTrue);
        throw Exception('Batch failure');
      });
    } catch (_) {}
    expect(Lx.isBatching, isFalse);
  });
}
