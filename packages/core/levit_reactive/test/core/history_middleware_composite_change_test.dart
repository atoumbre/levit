import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('handles composite change in undo/redo', () {
    final history = LevitReactiveHistoryMiddleware();
    Lx.addMiddleware(history);

    final a = 0.lx; final b = 0.lx;
    Lx.batch(() { a.value = 1; b.value = 1; });

    expect(history.length, 1);
    history.undo();
    expect(a.value, 0); expect(b.value, 0);

    history.redo();
    expect(a.value, 1); expect(b.value, 1);
  });
}
