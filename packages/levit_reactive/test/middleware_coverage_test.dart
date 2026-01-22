import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

// Helper to implement LxReactive for testing
class TestReactive<T> extends LxBase<T> {
  TestReactive(super.initial);
  set value(T v) => setValueInternal(v);
}

void main() {
  group('Middleware Coverage', () {
    test('LevitReactiveChange toString', () {
      final change = LevitReactiveChange(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 1,
        newValue: 2,
      );
      expect(change.toString(), contains('int: 1 → 2'));
    });

    test('LevitReactiveBatch logic', () {
      final batch = LevitReactiveBatch([]);
      expect(batch.isEmpty, true);
      expect(batch.isNotEmpty, false);
      expect(batch.length, 0);
      expect(batch.toString(), contains('Batch of 0 changes'));

      // Coverage for getters that do nothing/return null
      expect(batch.valueType, LevitReactiveBatch);
      // batch.oldValue; // void
      // batch.newValue; // void
      expect(batch.stackTrace, null);
      expect(batch.restore, null);

      // Stop propagation logic (inherited from LevitReactiveChange but overridden in Batch)
      batch.stopPropagation();
      expect(batch.isPropagationStopped, true);
    });

    // We can't easily test global static methods of LevitStateMiddlewareChain without affecting global state
    // properly, but we can verify StateHistory logic which is contained.

    test('StateHistoryMiddleware clear and print', () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = TestReactive<int>(0);

      Lx.addMiddleware(history);
      addTearDown(() => Lx.clearMiddlewares());

      rx.value = 1;

      expect(history.length, 1);
      expect(history.canUndo, true);

      history.printHistory(); // Should not crash

      history.clear();
      expect(history.length, 0);
      expect(history.canUndo, false);
    });

    test('StateHistoryMiddleware changesOfType', () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = TestReactive<int>(0);
      final rxStr = TestReactive<String>('a');

      Lx.addMiddleware(history);
      addTearDown(() => Lx.clearMiddlewares());

      rx.value = 1;
      rxStr.value = 'b';

      final intChanges = history.changesOfType(int);
      expect(intChanges.length, 1);
      expect(intChanges.first.newValue, 1);
    });
  });
}
