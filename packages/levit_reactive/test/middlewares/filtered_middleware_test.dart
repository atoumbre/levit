import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
// verify import path

class FilteredMiddlewareWrapper extends LevitReactiveMiddleware {
  final LevitReactiveMiddleware child;
  final bool Function(LxReactive, LevitReactiveChange) filter;

  FilteredMiddlewareWrapper(this.child, {required this.filter});

  @override
  LxOnSet? get onSet => child.onSet == null
      ? null
      : (next, reactive, change) {
          if (filter(reactive, change)) {
            return child.onSet!(next, reactive, change);
          }
          return next;
        };

  // Forward batch and dispose to child? Or bypass?
  // For history, batch is crucial. Assuming filter applies to atomic changes.
  // If batch contains mix of filtered/unfiltered?
  // History middleware 'onBatch' logic wraps execution.
  // If we filter atomic changes inside batch, onSet is called for each.
  // So wrapping onSet is sufficient.

  @override
  LxOnBatch? get onBatch => child.onBatch == null
      ? null
      : (next, change) {
          return child.onBatch!(next, change);
        };

  @override
  LxOnDispose? get onDispose => child.onDispose == null
      ? null
      : (next, reactive) {
          return child.onDispose!(next, reactive);
        };
}

void main() {
  group('FilteredMiddleware', () {
    late LevitReactiveHistoryMiddleware history;

    setUp(() {
      history = LevitReactiveHistoryMiddleware();
      // Ensure clean state
      Lx.clearMiddlewares();
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('should only record changes that pass the filter', () {
      final filteredHistory = FilteredMiddlewareWrapper(
        history,
        filter: (reactive, change) => change.valueType == int,
      );
      Lx.addMiddleware(filteredHistory);

      final ignoreObj = LxVar<String>('ignore');
      final recordObj = LxInt(0);

      // Should be ignored
      ignoreObj.value = 'updated';

      // Should be recorded
      recordObj.value = 10;

      expect(history.changes.length, 1);
      expect(history.changes.first.valueType, int);
      expect(history.changes.first.newValue, 10);

      // Verify undo works on the valid history
      history.undo();
      expect(recordObj.value, 0);
      expect(ignoreObj.value, 'updated'); // ignored obj should not revert
    });

    test('should allow removing filtered middleware', () {
      final filtered = FilteredMiddlewareWrapper(
        history,
        filter: (reactive, change) => true,
      );
      Lx.addMiddleware(filtered);

      expect(Lx.containsMiddleware(filtered), true);

      Lx.removeMiddleware(filtered);
      expect(Lx.containsMiddleware(filtered), false);
    });
  });
}
