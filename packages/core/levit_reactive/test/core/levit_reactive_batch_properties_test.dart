import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch properties', () {
    final composite = LevitReactiveBatch([]);

    expect((composite as dynamic).oldValue, isNull);
    expect((composite as dynamic).newValue, isNull);
    expect(composite.stackTrace, isNull);
    expect(composite.restore, isNull);
    expect(composite.toString(), contains('Batch'));
  });

  test('LevitReactiveBatch.fromChanges remains source-compatible', () {
    final batch = LevitReactiveBatch([]);

    expect(batch.entries, isEmpty);
    expect(batch.changes, isEmpty);
    expect(batch.reactiveVariables, isEmpty);
  });
}
