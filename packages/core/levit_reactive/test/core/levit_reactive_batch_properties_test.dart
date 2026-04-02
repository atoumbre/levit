import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch properties', () {
    final history = LevitReactiveHistoryMiddleware();
    Lx.addMiddleware(history);

    Lx.batch(() {
      0.lx.value = 1;
    });
    final composite = history.changes.first as LevitReactiveBatch;

    expect((composite as dynamic).oldValue, isNull);
    expect((composite as dynamic).newValue, isNull);
    expect(composite.stackTrace, isNull);
    expect(composite.restore, isNull);
    expect(composite.toString(), contains('Batch'));
  });

  test('LevitReactiveBatch.fromChanges remains source-compatible', () {
    // ignore: deprecated_member_use_from_same_package
    final batch = LevitReactiveBatch.fromChanges(<LevitReactiveChange>[]);

    expect(batch.entries, isEmpty);
    expect(batch.changes, isEmpty);
    expect(batch.reactiveVariables, isEmpty);
  });
}
