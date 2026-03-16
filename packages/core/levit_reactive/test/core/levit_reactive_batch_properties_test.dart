import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch properties', () {
    final history = LevitReactiveHistoryMiddleware();
    Lx.addMiddleware(history);

    Lx.batch(() { 0.lx.value = 1; });
    final composite = history.changes.first as LevitReactiveBatch;

    expect((composite as dynamic).oldValue, isNull);
    expect((composite as dynamic).newValue, isNull);
    expect(composite.stackTrace, isNull);
    expect(composite.restore, isNull);
    expect(composite.toString(), contains('Batch'));
  });
}
