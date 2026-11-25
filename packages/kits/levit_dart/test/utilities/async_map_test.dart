import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

void main() {
  test(
    'stream reports retained waiting, replacement error, recovery and closure',
    () async {
      var fail = false;
      final m = LevitAsyncMap<int, int?>(
        (_, _) => null,
        cachePolicy: (_) {
          if (fail) throw StateError('admission');
          return null;
        },
      );
      await m.fetch(1);
      final view = m.entry(1);
      expect(view.id, greaterThanOrEqualTo(0));
      final seen = <LxStatus<int?>>[];
      final sub = view.stream.listen(seen.add);
      fail = true;
      await expectLater(m.refresh(1), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(seen.whereType<LxWaiting<int?>>().first.hasLastValue, true);
      expect(seen.last, isA<LxError<int?>>());
      fail = false;
      await m.refresh(1);
      await sub.cancel();
      expect(view.isActive, false);
      await m.close();
      expect(await view.stream.isEmpty, true);
    },
  );
  test(
    'drain during failed producer retirement reports the failure after cleanup',
    () async {
      final map = LevitAsyncMap<int, int>((key, _) => key, name: 'test');
      await map.fetch(1);
      final hook = _FailProducerRelease();
      Levit.addStateMiddleware(hook);
      try {
        final checking = expectLater(
          map.refresh(1),
          throwsA(isA<LxCleanupException>()),
        );
        final draining = expectLater(
          map.drain(),
          throwsA(isA<LevitDisposalException>()),
        );
        await checking;
        await draining;
      } finally {
        Levit.removeStateMiddleware(hook);
        await map.close();
      }
    },
  );
  test(
    'explicit eviction drains pending refresh and closes the old view',
    () async {
      final release = Completer<void>(), started = Completer<void>();
      var generation = 0;
      final m = LevitAsyncMap<int, int>((k, context) async {
        if (++generation == 1) {
          started.complete();
          try {
            await context.cancelled;
          } finally {
            await release.future;
          }
        }
        return k;
      });
      final check = expectLater(
        m.refresh(1),
        throwsA(isA<LevitTaskCancelledException>()),
      );
      final old = m.peek(1)!;
      await started.future;
      var finished = false;
      final retiring = m.evict(1).then((_) => finished = true);
      expect(old.isClosed, true);
      expect(m.peek(1), isNull);
      expect(await m.fetch(1), 1);
      expect(finished, false);
      release.complete();
      await check;
      await retiring;
      expect(() => old.value, throwsStateError);
      await m.close();
    },
  );
  test(
    'initial admission failure reaches caller and entry, then later fetch retries',
    () async {
      var plans = 0;
      final m = LevitAsyncMap<int, int>(
        (k, _) => k,
        cachePolicy: (_) {
          if (++plans == 1) throw StateError('cache configuration');
          return null;
        },
      );
      await expectLater(m.fetch(4), throwsStateError);
      expect(m[4], isA<LxError<int>>());
      expect(plans, 1);
      expect(await m.fetch(4), 4);
      await m.close();
    },
  );

  test('reads and refreshes deduplicate; fetch respects freshness', () async {
    var now = DateTime(2026);
    var calls = 0;
    final results = <Completer<int>>[];
    final query = LevitAsyncMap<String, int>((key, context) {
      calls++;
      final pending = Completer<int>();
      results.add(pending);
      return pending.future;
    }, now: () => now);
    final handle = query.entry('search');
    expect(identical(handle, query.entry('search')), isTrue);
    final first = query.fetch('search');
    final refresh = query.refresh('search');
    expect(identical(refresh, query.refresh('search')), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    results.single.complete(10);
    expect(await first, 10);
    await refresh;
    expect(await query.fetch('search'), 10);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    final stale = query.fetch('search');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
    expect(handle.value, isA<LxWaiting<int>>());
    expect(handle.value.lastValue, 10);
    results.last.complete(20);
    expect(await stale, 20);
    expect(identical(query.entry('search'), handle), isTrue);
    await query.dispose();
  });

  test(
    'nullable retained data reaches waiting and error then recovers',
    () async {
      var calls = 0;
      final next = Completer<String?>();
      final query = LevitAsyncMap<String, String?>((key, context) {
        calls++;
        if (calls == 1) return null;
        if (calls == 2) return next.future;
        return 'recovered';
      });
      final handle = query.entry('q');
      expect(await query.fetch('q'), isNull);
      final observed = <LxStatus<String?>>[];
      void listener() => observed.add(handle.value);
      handle.addListener(listener);
      final refreshing = query.refresh('q');
      await Future<void>.delayed(Duration.zero);
      expect(handle.value, isA<LxWaiting<String?>>());
      expect(handle.value.hasLastValue, isTrue);
      expect(handle.value.lastValue, isNull);
      final failure = expectLater(refreshing, throwsStateError);
      next.completeError(StateError('offline'));
      await failure;
      expect(handle.value, isA<LxError<String?>>());
      expect(handle.value.hasLastValue, isTrue);
      expect(handle.value.lastValue, isNull);
      await query.refresh('q');
      expect(handle.value.lastValue, 'recovered');
      expect(observed.whereType<LxWaiting<String?>>(), isNotEmpty);
      handle.removeListener(listener);
      await query.dispose();
    },
  );

  test('retry uses task policy and publishes one successful result', () async {
    var tries = 0;
    final query = LevitAsyncMap<int, int>(
      (key, _) {
        if (++tries < 3) throw const FormatException('transient');
        return key * 2;
      },
      retryPolicy: LevitRetryPolicy(
        shouldRetry: (error, _) => error is FormatException,
        maxRetries: 2,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        jitter: 0,
      ),
    );
    expect(await query.fetch(4), 8);
    expect(tries, 3);
    await query.dispose();
  });

  test('closure cancels then drains the producer finally', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var finallyDone = false;
    final query = LevitAsyncMap<int, int>((key, context) async {
      started.complete();
      try {
        await context.cancelled;
        return 42;
      } finally {
        await release.future;
        finallyDone = true;
      }
    });
    final handle = query.entry(1);
    await started.future;
    final fetch = expectLater(
      query.fetch(1),
      throwsA(
        anyOf(isA<LevitTaskCancelledException>(), isA<LxCancelledException>()),
      ),
    );
    var closed = false;
    final cleanup = query.dispose().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    expect(finallyDone, isFalse);
    release.complete();
    await cleanup;
    await fetch;
    expect(finallyDone, isTrue);
    expect(handle.isClosed, isTrue);
  });

  test(
    'borrowed engine stays open and query cleanup failures propagate',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 2);
      final start = Completer<void>();
      final query = LevitAsyncMap<int, int>((key, context) async {
        start.complete();
        try {
          await context.cancelled;
          return 1;
        } finally {
          throw StateError('failed cleanup');
        }
      }, engine: engine);
      query.entry(1);
      await start.future;
      await expectLater(
        query.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
      expect(await engine.schedule((_) => 2), 2);
      await expectLater(
        engine.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
    },
  );

  test(
    'LRU cancels inactive requests and active handles stay pinned',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 4);
      final cancelled = <int>[];
      final query = LevitAsyncMap<int, int>(
        (key, context) async {
          await context.cancelled;
          cancelled.add(key);
          return key;
        },
        engine: engine,
        maxInactiveEntries: 1,
      );
      final pinned = query.entry(1);
      void listener() {}
      pinned.addListener(listener);
      final evicted = query.entry(2);
      query.entry(3);
      await Future<void>.delayed(Duration.zero);
      expect(query.length, 2);
      expect(evicted.isClosed, isTrue);
      expect(pinned.isClosed, isFalse);
      expect(() => query.evict(1), throwsStateError);
      pinned.removeListener(listener);
      await query.dispose();
      expect(cancelled, contains(1));
      await engine.dispose();
    },
  );

  test('query task cannot close or refresh its own map', () async {
    final gate = Completer<void>();
    late LevitAsyncMap<int, int> query;
    query = LevitAsyncMap((key, context) async {
      await gate.future;
      expect(() => query.dispose(), throwsStateError);
      expect(() => query.refresh(key), throwsStateError);
      return 1;
    });
    final result = query.fetch(1);
    gate.complete();
    expect(await result, 1);
    await query.dispose();
  });
}

class _FailProducerRelease extends LevitReactiveMiddleware {
  @override
  LevitReactiveOnDispose get onDispose =>
      (next, source) => () {
        next();
        if (source is LxFuture) throw StateError('producer close');
      };
}
