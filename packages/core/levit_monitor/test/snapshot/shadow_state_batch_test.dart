import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  test('LevitStateSnapshot should handle LevitReactiveBatchEvent', () {
    final state = LevitStateSnapshot();
    final sid = 'test-session';
    final rx = 0.lx; // Create a reactive variable
    rx.name = 'test_rx';
    rx.ownerId = 'scope:ctrl';

    // Initialize the reactive in shadow state
    state.applyEvent(LevitReactiveInitEvent(sessionId: sid, reactive: rx));

    // Assert initialization using correct ID
    expect(
      state.variables.containsKey(rx.id),
      isTrue,
      reason: 'Variable should be present after InitEvent',
    );

    // Create a batch event
    final change = LevitReactiveChange(
      timestamp: DateTime.now(),
      valueType: int,
      oldValue: 0,
      newValue: 42,
    );

    final batch = LevitReactiveBatch([(rx, change)]);
    final batchEvent = LevitReactiveBatchEvent(sessionId: sid, change: batch);

    state.applyEvent(batchEvent);

    // Shadow state should be updated with the value from the batch
    expect(
      state.variables[rx.id]?.value,
      '42',
      reason: 'Value should be updated by BatchEvent',
    );
    expect(
      state.variables[rx.id]?.valueType,
      'int',
      reason: 'Value type should be updated by BatchEvent',
    );
  });

  test('LevitStateSnapshot batch keeps sensitive values obfuscated', () {
    final state = LevitStateSnapshot();
    final sid = 'test-session';
    final rx = 'secret-token'.lxVar(name: 'token', isSensitive: true);

    state.applyEvent(LevitReactiveInitEvent(sessionId: sid, reactive: rx));

    final change = LevitReactiveChange<String>(
      timestamp: DateTime.now(),
      valueType: String,
      oldValue: 'secret-token',
      newValue: 'new-secret-token',
    );
    final batch = LevitReactiveBatch([(rx, change)]);
    state.applyEvent(LevitReactiveBatchEvent(sessionId: sid, change: batch));

    expect(state.variables[rx.id]?.value, '***');
    expect(state.variables[rx.id]?.valueType, 'String');
  });
}
