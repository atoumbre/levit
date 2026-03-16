import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveBatch logic', () {
    final batch = LevitReactiveBatch([]);
    expect(batch.isEmpty, true);
    expect(batch.isNotEmpty, false);
    expect(batch.length, 0);
    expect(batch.toString(), contains('Batch of 0 changes'));
    expect(batch.valueType, LevitReactiveBatch);
    expect(batch.stackTrace, null);
    expect(batch.restore, null);
    batch.stopPropagation();
    expect(batch.isPropagationStopped, true);
  });
}
