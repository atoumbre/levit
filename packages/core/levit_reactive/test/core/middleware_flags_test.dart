import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override
  LevitReactiveOnSet? get onSet =>
      (next, reactive, change) => (value) {};
  @override
  LevitReactiveOnBatch? get onBatch =>
      (next, change) =>
          () => throw StateError('Batch rejected');
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];
  @override
  LevitReactiveOnSet? get onSet =>
      (next, reactive, change) => (value) {
        next(value);
        changes.add(change);
      };
}

void main() {
  test('mutation interceptor observes sets only while registered', () {
    Lx.clearMiddlewares();
    final mw = TestSimpleMiddleware();
    final value = 0.lx;
    value.value = 1;
    expect(mw.changes, isEmpty);

    Lx.addMiddleware(mw);
    value.value = 2;
    expect(mw.changes, hasLength(1));

    Lx.removeMiddleware(mw);
    value.value = 3;
    expect(mw.changes, hasLength(1));
  });
}
