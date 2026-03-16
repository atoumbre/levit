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
  test('CompositeChange getters return correct metadata', () {
    final rx = 0.lx;
    final change1 = LevitReactiveChange<int>(timestamp: DateTime.now(), valueType: int, oldValue: 0, newValue: 1);
    final composite = LevitReactiveBatch([(rx, change1)]);

    try { composite.oldValue; } catch (_) {}
    try { composite.newValue; } catch (_) {}

    expect(composite.stackTrace, isNull);
    expect(composite.toString(), contains('Batch'));
    expect(composite.valueType, equals(LevitReactiveBatch));
    expect(composite.restore, isNull);
    expect(composite.reactiveVariables, contains(rx));
    expect(composite.length, 1);
    expect(composite.isEmpty, isFalse);
    expect(composite.isNotEmpty, isTrue);
  });
}
