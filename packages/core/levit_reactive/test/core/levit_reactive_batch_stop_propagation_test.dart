import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch stopPropagation', () {
    final history = LevitReactiveHistoryMiddleware();
    Lx.addMiddleware(history);
    Lx.batch(() {
      0.lx.value = 1;
    });

    final composite = history.changes.first as LevitReactiveBatch;
    expect(composite.isPropagationStopped, isFalse);

    composite.stopPropagation();
    expect(composite.isPropagationStopped, isTrue);
  });
}
