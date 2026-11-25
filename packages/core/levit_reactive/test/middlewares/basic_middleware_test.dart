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
}
