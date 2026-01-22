import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'dart:async';

void main() {
  group('Middleware Coverage', () {
    tearDown(() {
      Lx.clearMiddlewares();
      Lx.captureStackTrace = false;
    });

    group('LevitReactiveHistoryMiddleware', () {
      test('undo/redo return false when empty', () {
        final history = LevitReactiveHistoryMiddleware();
        expect(history.undo(), isFalse);
        expect(history.redo(), isFalse);
      });

      test('changesOfType filters correctly', () {
        final history = LevitReactiveHistoryMiddleware();
        Lx.addMiddleware(history);

        final a = LxInt(0);
        final b = LxVar<String>('');

        a.value = 1;
        b.value = 'hi';
        a.value = 2;

        expect(history.changesOfType(int).length, equals(2));
        expect(history.changesOfType(String).length, equals(1));
      });

      test('printHistory output', () {
        final logs = <String>[];
        final history = LevitReactiveHistoryMiddleware();

        runZoned(() {
          Lx.addMiddleware(history);
          final count = 0.lx;
          count.value = 1;
          history.undo();
          history.printHistory();
        }, zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
          },
        ));

        expect(logs, contains('--- Undo Stack ---')); // even if empty
        expect(logs, contains('--- Redo Stack ---'));
        expect(logs.any((l) => l.contains('0 → 1')), isTrue);
      });

      test('handles composite change in undo/redo', () {
        final history = LevitReactiveHistoryMiddleware();
        Lx.addMiddleware(history);

        final a = 0.lx;
        final b = 0.lx;

        Lx.batch(() {
          a.value = 1;
          b.value = 1;
        });

        expect(history.length, equals(1)); // 1 composite change

        history.undo();
        expect(a.value, equals(0));
        expect(b.value, equals(0));

        history.redo();
        expect(a.value, equals(1));
        expect(b.value, equals(1));
      });
    });

    group('Lx Core Coverage', () {
      test('onListen and onCancel callbacks', () async {
        bool listened = false;
        bool cancelled = false;

        final count = LxVar(
          0,
          onListen: () => listened = true,
          onCancel: () => cancelled = true,
        );

        final sub = count.stream.listen((_) {});
        await Future.delayed(Duration.zero);
        expect(listened, isTrue);

        await sub.cancel();
        await Future.delayed(Duration.zero);
        expect(cancelled, isTrue);
      });

      test('bind handles errors', () async {
        final controller = StreamController<int>();
        final count = 0.lx;
        count.bind(controller.stream);

        // We expect the error to be propagated
        final future = expectLater(count.stream, emitsError('Stream Error'));

        controller.addError('Stream Error');

        await future;
        await controller.close();
      });

      test('equality checks', () {
        final count = 1.lx;
        final count2 = 1.lx;
        final diff = 2.lx;

        expect(count == count, isTrue);
        expect(count == count2, isFalse); // Identity
        // ignore: unrelated_type_equality_checks
        expect(count == 1, isFalse); // Identity
        expect(count.value, equals(1));

        // ignore: unrelated_type_equality_checks
        expect(count == diff, isFalse);
        // ignore: unrelated_type_equality_checks
        expect(count == 2, isFalse);
        // ignore: unrelated_type_equality_checks
        expect(count == Object(), isFalse);

        expect(count.toString(), equals('1'));
      });

      test('LevitReactiveBatch properties', () {
        final history = LevitReactiveHistoryMiddleware();
        Lx.addMiddleware(history);

        Lx.batch(() {
          0.lx.value = 1;
        });

        // Verify LevitReactiveBatch specific getters
        final composite = history.changes.first as LevitReactiveBatch;

        // Access via dynamic to handle 'void' return type in tests
        expect((composite as dynamic).oldValue, isNull);
        expect((composite as dynamic).newValue, isNull);

        expect(composite.stackTrace, isNull);
        expect(composite.restore, isNull);
        expect(composite.toString(), contains('Batch'));
      });

      test('LevitReactiveBatch stopPropagation', () {
        final history = LevitReactiveHistoryMiddleware();
        Lx.addMiddleware(history);
        Lx.batch(() {
          0.lx.value = 1;
        });

        final composite = history.changes.first as LevitReactiveBatch;
        expect(composite.isPropagationStopped, isFalse);

        composite.stopPropagation();
        expect(composite.isPropagationStopped, isTrue);
      });
    });
  });
}
