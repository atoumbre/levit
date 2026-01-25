import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('StateSnapshot should handle ReactiveBatchEvent', () {
    final state = StateSnapshot();
    final sid = 'test-session';
    final rx = 0.lx; // Create a reactive variable
    rx.name = 'test_rx';
    rx.ownerId = 'scope:ctrl';

    // Initialize the reactive in shadow state
    state.applyEvent(ReactiveInitEvent(sessionId: sid, reactive: rx));

    // Assert initialization using correct ID
    expect(state.variables.containsKey(rx.id), isTrue,
        reason: 'Variable should be present after InitEvent');

    // Create a batch event
    final change = LevitReactiveChange(
      timestamp: DateTime.now(),
      valueType: int,
      oldValue: 0,
      newValue: 42,
    );

    final batch = LevitReactiveBatch([(rx, change)]);
    final batchEvent = ReactiveBatchEvent(sessionId: sid, change: batch);

    state.applyEvent(batchEvent);

    // Shadow state should be updated with the value from the batch
    expect(state.variables[rx.id]?.value, '42',
        reason: 'Value should be updated by BatchEvent');
  });
}
