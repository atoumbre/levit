import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override LxOnSet? get onSet => (next, reactive, change) => (value) {};
  @override LxOnBatch? get onBatch => (next, change) => () => throw StateError('Batch rejected');
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];
  @override LxOnSet? get onSet => (next, reactive, change) => (value) { next(value); changes.add(change); };
}

void main() {
  group('LevitReactiveHistoryMiddleware Extra', () {
    test('handles missing name/callback gracefully', () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = 0.lx;
      final brokenChange = LevitReactiveChange<int>(timestamp: DateTime.now(), valueType: int, oldValue: 0, newValue: 1);

      bool nextCalled = false;
      void next(dynamic v) => nextCalled = true;
      history.onSet!(next, rx, brokenChange)(1);

      expect(nextCalled, isTrue);
      expect(history.undo(), isTrue);
    });

    test('clean works', () {
      final history = LevitReactiveHistoryMiddleware();
      final count = 0.lx;
      Lx.addMiddleware(history);

      count.value = 1;
      expect(history.changes, isNotEmpty);

      history.clear();
      expect(history.changes, isEmpty);
    });
  });
}
