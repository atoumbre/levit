import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveHistoryMiddleware redoChanges', () {
    final mw = LevitReactiveHistoryMiddleware();
    mw.redoChanges;
  });
}
