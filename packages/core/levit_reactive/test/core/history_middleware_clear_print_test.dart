import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> {
  TestReactive(super.initial);
}

void main() {
  test('StateHistoryMiddleware clear and print', () {
    final history = LevitReactiveHistoryMiddleware();
    final rx = TestReactive<int>(0);

    Lx.addMiddleware(history);
    addTearDown(() => Lx.clearMiddlewares());

    rx.value = 1;

    expect(history.length, 1);
    expect(history.canUndo, true);

    history.printHistory();

    history.clear();
    expect(history.length, 0);
    expect(history.canUndo, false);
  });
}
