import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestReactive<T> extends LxVar<T> { TestReactive(super.initial); }

void main() {
  test('StateHistoryMiddleware changesOfType', () {
    final history = LevitReactiveHistoryMiddleware();
    final rx = TestReactive<int>(0);
    final rxStr = TestReactive<String>('a');

    Lx.addMiddleware(history);
    addTearDown(() => Lx.clearMiddlewares());

    rx.value = 1;
    rxStr.value = 'b';

    final intChanges = history.changesOfType(int);
    expect(intChanges.length, 1);
    expect(intChanges.first.newValue, 1);
  });

  test('changesOfType filters correctly (Alternative)', () {
    final history = LevitReactiveHistoryMiddleware();
    Lx.addMiddleware(history);

    final a = LxInt(0);
    final b = LxVar<String>('');

    a.value = 1;
    b.value = 'hi';
    a.value = 2;

    expect(history.changesOfType(int).length, equals(2));
    expect(history.changesOfType(String).length, equals(1));
  });
}