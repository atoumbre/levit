import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../helpers.dart';

void main() {
  group('LevitReactiveMiddleware', () {
    setUp(() {
      Lx.clearMiddlewares();
      Lx.captureStackTrace = false;
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('middleware receives state changes', () async {
      final changes = <LevitReactiveChange>[];
      Lx.addMiddleware(TestMiddleware(onAfter: changes.add));

      final count = LxInt(0);
      count.value = 1;
      count.value = 2;

      expect(changes, hasLength(2));
      expect(changes[0].oldValue, equals(0));
      expect(changes[0].newValue, equals(1));
      expect(changes[1].oldValue, equals(1));
      expect(changes[1].newValue, equals(2));
    });

    test('LevitReactiveChange toString includes type info', () {
      final change = LevitReactiveChange<int>(
        timestamp: DateTime(2024, 1, 1),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );

      final str = change.toString();
      expect(str, contains('int'));
      expect(str, contains('0'));
      expect(str, contains('1'));
    });

    test('onBeforeChange can prevent state change', () {
      Lx.addMiddleware(TestMiddleware(allowChange: false));

      final count = LxInt(0);
      count.value = 100;

      expect(count.value, equals(0)); // Change was prevented
    });

    test('captureStackTrace captures stack when enabled', () {
      final changes = <LevitReactiveChange>[];
      Lx.captureStackTrace = true;
      Lx.addMiddleware(TestMiddleware(onAfter: changes.add));

      final count = LxInt(0);
      count.value = 1;

      expect(changes.first.stackTrace, isNotNull);
    });

    test('default onBeforeChange allows changes', () {
      final minimal = MinimalMiddleware();
      Lx.addMiddleware(minimal);

      final count = LxInt(0);
      count.value = 5;

      expect(count.value, equals(5)); // Change was allowed
      expect(minimal.changes, hasLength(1));
    });

    test('LevitReactiveMiddleware default onSet returns null', () {
      final middleware = DefaultMiddleware();
      expect(middleware.onSet, isNull);
    });
  });

  group('LevitReactiveHistoryMiddleware (Basic)', () {
    late LevitReactiveHistoryMiddleware history;

    setUp(() {
      history = LevitReactiveHistoryMiddleware();
      Lx.addMiddleware(history);
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('records state changes', () {
      final count = LxInt(0);
      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(history.length, equals(3));
      expect(history.changes[0].newValue, equals(1));
      expect(history.changes[1].newValue, equals(2));
      expect(history.changes[2].newValue, equals(3));
    });

    test('respects maxHistorySize', () {
      LevitReactiveHistoryMiddleware.maxHistorySize = 2;

      final count = 0.lx;
      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(history.length, equals(2)); // Only last 2
      expect(history.changes[0].newValue, equals(2));
      expect(history.changes[1].newValue, equals(3));

      LevitReactiveHistoryMiddleware.maxHistorySize = 100; // Reset
    });

    test('changesOfType filters by type', () {
      final a = LxInt(0);
      final b = LxVar<String>('');

      a.value = 1;
      b.value = 'hello';
      a.value = 3;

      expect(history.changesOfType(int), hasLength(2));
      expect(history.changesOfType(String), hasLength(1));
    });

    test('clear removes all history', () {
      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      expect(history.length, equals(2));
      history.clear();
      expect(history.length, equals(0));
    });

    test('canUndo returns correct state', () {
      expect(history.canUndo, isFalse);

      final count = 0.lx;
      count.value = 1;

      expect(history.canUndo, isTrue);
    });

    test('changes list returns all changes', () {
      final count = LxInt(0);
      count.value = 1;
      count.value = 2;

      expect(history.changes.last.newValue, equals(2));
    });

    test('undo works automatically', () {
      final count = LxInt(0);

      count.value = 5;
      count.value = 10;

      expect(history.canUndo, isTrue);

      history.undo();
      expect(count.value, equals(5));

      history.undo();
      expect(count.value, equals(0));
    });

    test('undo returns false when no changes', () {
      expect(history.undo(), isFalse);
    });

    test('undo returns true by default (Auto-Undo)', () {
      final count = 0.lx;
      count.value = 1;

      // Even without manual registration, undo works via Auto-Undo
      final undone = history.undo();
      expect(undone, isTrue);
      expect(count.value, equals(0));
    });

    test('printHistory prints all changes', () {
      final count = LxInt(0);
      count.value = 1;

      // Just verify it doesn't throw
      history.printHistory();
    });
  });
}
