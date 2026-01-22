import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class TestRejectMiddleware extends LevitReactiveMiddleware {
  @override
  LxOnSet? get onSet => (next, reactive, change) {
        // Reject: do NOT call next
        return (value) {};
      };

  @override
  LxOnBatch? get onBatch => (next, change) {
        // Reject: throw StateError as per test expectation
        return () => throw StateError('Batch rejected');
      };
}

class TestSimpleMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          changes.add(change);
        };
      };
}

void main() {
  group('Coverage Gaps - Core', () {
    tearDown(() {
      Lx.clearMiddlewares();
      Lx.captureStackTrace = false;
    });

    test('Lx.runBatch resets isBatching on exception', () {
      expect(Lx.isBatching, isFalse);
      try {
        Lx.batch(() {
          expect(Lx.isBatching, isTrue);
          throw Exception('Batch failure');
        });
      } catch (_) {}
      expect(Lx.isBatching, isFalse);
    });

    test('LevitReactiveNotifier ignores operations after disposal', () {
      final notifier = LevitReactiveNotifier();
      var called = false;
      notifier.addListener(() => called = true);

      notifier.dispose();
      expect(notifier.isDisposed, isTrue);

      // Should result in no-op, no error
      notifier.notify();
      expect(called, isFalse);

      // Add listener after dispose should be ignored
      notifier.addListener(() => called = true);
    });

    test('LevitReactiveNotifier removeListener works', () {
      final notifier = LevitReactiveNotifier();
      var count = 0;
      void listener() => count++;

      notifier.addListener(listener);
      notifier.notify();
      expect(count, equals(1));

      notifier.removeListener(listener);
      notifier.notify();
      expect(count, equals(1)); // No increase
    });

    test('CompositeChange getters return correct metadata', () {
      final rx = 0.lx;
      final change1 = LevitReactiveChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );
      final composite = LevitReactiveBatch([(rx, change1)]);

      // Force access invalid getters for coverage
      try {
        composite.oldValue;
      } catch (_) {}
      try {
        composite.newValue;
      } catch (_) {}

      expect(composite.stackTrace, isNull);
      expect(composite.toString(), contains('Batch'));

      // Cover valueType, restore getters
      expect(composite.valueType, equals(LevitReactiveBatch));
      expect(composite.restore, isNull);

      // New getters coverage
      expect(composite.reactiveVariables, contains(rx));
      expect(composite.length, 1);
      expect(composite.isEmpty, isFalse);
      expect(composite.isNotEmpty, isTrue);

      // Legacy factory coverage
      expect(LevitReactiveBatch.fromChanges([]).isEmpty, isTrue);
    });

    test('Lx.hasSetMiddlewares coverage', () {
      Lx.clearMiddlewares();
      expect(LevitReactiveMiddleware.hasSetMiddlewares, isFalse);
      Lx.addMiddleware(TestSimpleMiddleware());
      expect(LevitReactiveMiddleware.hasSetMiddlewares, isTrue);
    });

    test('Lx bind handles stream errors', () async {
      final controller = StreamController<int>();
      final count = 0.lx;

      // Bind (lazy)
      count.bind(controller.stream);

      // Must listen to activate the binding
      final events = <dynamic>[];
      final sub = count.stream.listen(
        (v) => events.add(v),
        onError: (e) => events.add('Error: $e'),
      );

      controller.addError('Stream Error');
      controller.add(5);

      await Future.delayed(Duration.zero);
      // Wait a bit more for async propagation if needed
      await Future.delayed(Duration(milliseconds: 10));

      expect(events, contains(5));
      expect(count.value, equals(5));

      await sub.cancel();
      await controller.close();
    });

    test('Middleware cancellation prevents updates', () {
      Lx.addMiddleware(TestRejectMiddleware());

      // Test Lx
      final count = 0.lx;
      count.value = 1;
      expect(count.value, equals(0)); // Rejected

      // Test Lxn
      final name = 'a'.lxNullable;
      name.value = 'b';
      expect(name.value, equals('a')); // Rejected

      // Test Batch cancellation
      expect(() => Lx.batch(() {}), throwsStateError);

      // Test BatchAsync cancellation
      expect(() => Lx.batchAsync(() async {}), throwsStateError);
    });

    test('LevitReactiveMiddleware default implementations', () {
      // Create a specific class that extends (not implements) to use default methods
      final simpleMiddleware = TestSimpleMiddleware();
      Lx.addMiddleware(simpleMiddleware);

      // Trigger default onSet (should pass through and record)
      final count = 0.lx;
      count.value = 1;
      expect(count.value, equals(1));
      expect(simpleMiddleware.changes, hasLength(1));

      // Trigger default onBatch
      // TestSimpleMiddleware doesn't override onBatch to crash, it uses default (pass-through)
      // Wait, TestSimpleMiddleware DOES NOT override onBatch.
      // So it inherits default LevitReactiveMiddleware.onBatch => return next.
      Lx.batch(() {
        count.value = 2;
      });
      expect(count.value, equals(2));

      // No crash means defaults worked
    });
  });

  group('LevitReactiveHistoryMiddleware Extra Coverage', () {
    test(
        'LevitReactiveHistoryMiddleware handles missing name/callback gracefully',
        () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = 0.lx;
      // Manually add a change with NO restore callback and NO name
      final brokenChange = LevitReactiveChange<int>(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
        // name: null, // default
        // restore: null // default
      );

      // Manually simulate wrapper to inject brokenChange
      bool nextCalled = false;
      void next(dynamic v) => nextCalled = true;
      history.onSet!(next, rx, brokenChange)(1);

      expect(nextCalled, isTrue);

      // Undo should hit the "Warning" print path but not crash
      // Since it returns true (change popped), we verify that.
      expect(history.undo(), isTrue);
    });

    test('LevitReactiveHistoryMiddleware clear works', () {
      final history = LevitReactiveHistoryMiddleware();
      final count = 0.lx;
      Lx.addMiddleware(history); // Activate

      count.value = 1;
      expect(history.changes, isNotEmpty);

      history.clear();
      expect(history.changes, isEmpty); // access changes getter
      expect(history.length, equals(0)); // access length getter
    });

    test('LevitReactiveHistoryMiddleware printHistory with redo stack', () {
      final history = LevitReactiveHistoryMiddleware();
      Lx.addMiddleware(history);

      final count = 0.lx;
      count.value = 1;
      count.value = 2;

      // Undo to populate redo stack
      history.undo();
      expect(history.canRedo, isTrue);

      // This should print both undo and redo stacks
      history.printHistory();
      // No assertion needed - just coverage
    });
  });

  group('Types Extra Coverage', () {
    test('Lx convenience methods (mutate, refresh, call, updateValue)', () {
      final count = 0.lx;

      // .call()
      expect(count(), equals(0));
      expect(count(5), equals(5));
      expect(count.value, equals(5));

      // updateValue
      count.updateValue((v) => v * 2);
      expect(count.value, equals(10));

      // refresh / notify
      // We need a listener to verify notification
      var notifications = 0;
      count.addListener(() => notifications++);

      count.refresh();
      expect(notifications, equals(1));

      count.notify();
      expect(notifications, equals(2));

      // mutate
      final list = <int>[].lx;
      list.addListener(() => notifications++);
      list.mutate((l) => l.add(1));
      expect(notifications, equals(3)); // list added
      expect(list.value, equals([1]));
    });

    test('LxNullable setNull', () {
      final name = 'test'.lxNullable;
      expect(name.value, equals('test'));
      name.value = null;
      expect(name.value, isNull);
    });

    test('Future.lx extension creates LxFuture', () async {
      final future = Future.value(42);
      final lxFuture = future.lx;

      expect(lxFuture, isA<LxFuture<int>>());

      // Wait for completion
      await Future.delayed(Duration(milliseconds: 10));
      expect(lxFuture.status, isA<LxSuccess<int>>());
      expect(lxFuture.valueOrNull, equals(42));
    });

    test('LevitStateCore flushGlobalBatch resets isBatching on exception', () {
      final rx = 0.lx;
      rx.addListener(() {
        throw Exception('Listener error');
      });

      final rx2 = 0.lx;
      var processed = false;
      rx2.addListener(() {
        processed = true;
      });

      expect(Lx.isBatching, isFalse);

      try {
        Lx.batch(() {
          rx.value = 1;
          rx2.value = 1;
        });
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('Listener error'));
      }

      // Critical: isBatching must be reset even after exception
      expect(Lx.isBatching, isFalse);
      expect(processed, isFalse);

      // Note: rx2's listener may or may not have been called depending on
      // the order of notification. The important thing is isBatching is reset.
    });

    test('Lx.refresh records batch entry', () {
      final rx = 0.lx;
      final mw = TestSimpleMiddleware();
      Lx.addMiddleware(mw);

      Lx.batch(() {
        rx.refresh();
      });

      expect(mw.changes, hasLength(1));
    });

    test('Additional granular middleware flags', () {
      Lx.clearMiddlewares();
      expect(LevitReactiveMiddleware.hasBatchMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasDisposeMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasGraphChangeMiddlewares, isFalse);
    });

    test('LevitReactiveHistoryMiddleware onBatch during restore', () {
      final history = LevitReactiveHistoryMiddleware();
      final rx = 0.lx;
      Lx.addMiddleware(history);

      final customChange = LevitReactiveChange<int>(
          timestamp: DateTime.now(),
          valueType: int,
          oldValue: 0,
          newValue: 1,
          restore: (v) {
            Lx.batch(() {});
          });

      // Inject the custom change manually
      void next(dynamic v) {}
      history.onSet!(next, rx, customChange)(1);

      expect(history.canUndo, isTrue);
      history.undo(); // Hitting line 413
    });

    test('LxWatch stream listener coverage', () async {
      final rx = 0.lx;
      var count = 0;
      final watch =
          LxWatch(rx, (v) => count++, onError: (e, s) => print('Caught $e'));

      rx.value = 1;
      await Future.delayed(Duration.zero);
      expect(count, 1);

      watch.close();
    });
  });
}
