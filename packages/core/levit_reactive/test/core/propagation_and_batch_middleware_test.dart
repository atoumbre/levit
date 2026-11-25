import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _BatchOnlyMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveBatch> batches = [];

  @override
  LevitReactiveOnBatch? get onBatch => (next, change) {
    return () {
      final result = next();
      batches.add(change);
      return result;
    };
  };
}

class _ThrowingWaitingMiddleware extends LevitReactiveMiddleware {
  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
    return (value) {
      if (value is LxWaiting) {
        throw StateError('waiting blocked');
      }
      next(value);
    };
  };
}

void main() {
  tearDown(() {
    Lx.clearMiddlewares();
  });

  group('Batch-only middleware recording', () {
    test('records refresh and collection entry updates inside Lx.batch', () {
      final mw = _BatchOnlyMiddleware();
      Lx.addMiddleware(mw);

      final counter = 1.lx;
      final map = <String, int>{'a': 1}.lx;
      final entry = map.entry('a');
      var entryEvents = 0;
      entry.addListener(() => entryEvents++);

      Lx.batch(() {
        counter.refresh();
        map['a'] = 2;
      });

      expect(entryEvents, 1);
      expect(mw.batches, isNotEmpty);
      expect(mw.batches.last.length, greaterThanOrEqualTo(2));

      map.close();
      counter.close();
    });
  });

  group('Topological propagation ordering and recovery', () {
    test(
      'dequeues shallower sources ahead of deeper computeds and skips nulled slots',
      () {
        final a = 0.lx;
        final b = 0.lx;
        final c = 0.lx;
        final d1 = LxComputed(() => a.value + 1);
        final d2 = LxComputed(() => d1.value + 1);
        final log = <String>[];

        // Subscribe d2 -> d1 -> a first so d1 (depth 1) enqueues before b (depth 0).
        d1.addListener(() {
          log.add('d1:${d1.value}');
        });
        d2.addListener(() {
          log.add('d2:${d2.value}');
          if (d2.value == 3) {
            c.value = 1;
          }
        });
        a.addListener(() {
          if (a.value == 1) {
            b.value = 1;
          }
        });
        b.addListener(() {
          log.add('b:${b.value}');
        });
        c.addListener(() {
          log.add('c:${c.value}');
        });

        // Prime computeds so their dependency edges and depths are established.
        expect(d2.value, 2);

        a.value = 1;

        expect(log, containsAllInOrder(['b:1', 'd1:2', 'd2:3', 'c:1']));

        d2.close();
        d1.close();
        a.close();
        b.close();
        c.close();
      },
    );

    test('clears pending flags when a listener throws during propagation', () {
      final a = 0.lx;
      final b = 0.lx;
      final c = 0.lx;
      var cCount = 0;

      a.addListener(() {});
      a.addListener(() {
        b.value = a.value;
        c.value = a.value;
      });
      b.addListener(() {
        if (b.value == 1) throw StateError('listener failure');
      });
      c.addListener(() => cCount++);

      expect(() => a.value = 1, throwsStateError);

      // Subsequent updates to c still propagate normally after recovery.
      c.value = 2;
      expect(cCount, 1);

      a.close();
      b.close();
      c.close();
    });
  });

  group('Async computed waiting transition failure', () {
    test('cleans up execution state when emitting LxWaiting throws', () async {
      final source = 1.lx;
      final computed = LxComputed.async(
        () async => source.value * 10,
        initial: 0,
      );
      final mw = _ThrowingWaitingMiddleware();
      Lx.addMiddleware(mw);

      void noop() {}
      expect(() => computed.addListener(noop), throwsStateError);

      Lx.clearMiddlewares();
      computed.removeListener(noop);
      await computed.close();
      await source.close();
    });
  });
}
