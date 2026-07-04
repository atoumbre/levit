import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('undo/redo return false when empty', () {
    final history = LevitReactiveHistoryMiddleware();
    expect(history.undo(), isFalse);
    expect(history.redo(), isFalse);
  });
}
