import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

import '../core/cleanup_failure_acceptance_test.dart' show DisposeHook;

class Producer extends LxVar<int> {
  Producer(super.value);
  Object? detachError;
  @override
  void removeListener(void Function() callback) {
    super.removeListener(callback);
    if (detachError != null) throw detachError!;
  }

  Object? readError;
  Object? cancelError;
  Object? drainError;
  Object? closeError;
  Completer<void>? gate;
  @override
  int get value {
    if (readError != null) throw readError!;
    return super.value;
  }

  @override
  void requestCancel() {
    super.requestCancel();
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> drain() async {
    await gate?.future;
    if (drainError != null) throw drainError!;
    await super.drain();
  }

  @override
  Future<void> close() async {
    await gate?.future;
    try {
      await super.close();
    } finally {
      if (closeError != null) throw closeError!;
    }
  }
}

Matcher failures(Iterable<Object> errors) => isA<LxCleanupException>().having(
  (e) => e.failures.map((f) => f.error),
  'failures',
  unorderedEquals(errors),
);

void main() {
  tearDown(LevitReactiveMiddleware.clear);

  test(
    'replacement failure combines first read and cleanup errors; closed streams terminate',
    () async {
      final read = StateError('cannot read'),
          close = StateError('cannot release');
      var gen = 0;
      final resource = LxResource<int, Producer>(() {
        final p = Producer(++gen);
        if (gen == 2) {
          p.readError = read;
          p.closeError = close;
        }
        return p;
      });
      resource.value;
      await expectLater(resource.refresh(), throwsA(failures([read, close])));
      await resource.refresh();
      final detach = StateError('detach');
      resource.producer.detachError = detach;
      await expectLater(resource.close(), throwsA(failures([detach])));
      expect(await resource.stream.isEmpty, true);
    },
  );
  test(
    'a reentrant observer may join replacement before requesting closure',
    () async {
      var generation = 0;
      final r = LxResource<int, Producer>(() => Producer(++generation));
      Future<void>? joined, closing;
      r.addListener(() {
        if (r.isReplacing) {
          joined = r.refresh();
        } else if (r.lastValue == 2) {
          closing = r.close();
        }
      });
      final refresh = r.refresh();
      expect(joined, same(refresh));
      await expectLater(refresh, throwsA(isA<LxCancelledException>()));
      await closing;
      expect(r.isDisposed, true);
    },
  );
  test(
    'stream observation of an unused failing factory reports the error',
    () async {
      final problem = StateError('setup'), events = <Object>[];
      final r = LxResource<int, Producer>(() => throw problem);
      final subscription = r.stream.listen((_) {}, onError: events.add);
      await Future<void>.delayed(Duration.zero);
      expect(events, [problem]);
      await subscription.cancel();
      await r.close();
    },
  );
  test(
    'failed initial read closes unattached producer and reports its cleanup',
    () async {
      final read = StateError('read');
      final cancel = StateError('cancel');
      final close = StateError('close');
      final producer = Producer(1)
        ..readError = read
        ..cancelError = cancel
        ..closeError = close;
      final resource = LxResource<int, Producer>(() => producer);
      expect(() => resource.value, throwsA(same(read)));
      expect(resource.hasLastValue, isFalse);
      await expectLater(resource.close(), throwsA(failures([cancel, close])));
      expect(producer.isDisposed, isTrue);
    },
  );

  test(
    'failed producer reads remain observable and recover on next publication',
    () async {
      final producer = Producer(1);
      final resource = LxResource<int, Producer>(() => producer);
      final handle = resource;
      handle.value;
      final error = StateError('read failed');
      final errors = <Object>[];
      final values = <int>[];
      final subscription = handle.stream.listen(
        values.add,
        onError: errors.add,
      );
      producer.readError = error;
      producer.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(handle.refreshStackTrace, isNotNull);
      expect(handle.lastValue, 1);
      expect(errors, [error]);
      producer.readError = null;
      producer.value = 2;
      await Future<void>.delayed(Duration.zero);
      expect(values, [2]);
      expect(handle.refreshError, isNull);
      await subscription.cancel();
      await resource.close();
    },
  );

  test(
    'refresh aggregates cancellation and close failures and permits retry',
    () async {
      final cancel = StateError('cancel');
      final close = StateError('close');
      var generation = 0;
      final resource = LxResource<int, Producer>(() => Producer(++generation));
      final handle = resource;
      handle.value;
      handle.producer
        ..cancelError = cancel
        ..closeError = close;
      await expectLater(resource.refresh(), throwsA(failures([cancel, close])));
      expect(handle.refreshStackTrace, isNotNull);
      expect(handle.lastValue, 1);
      await resource.refresh();
      expect(handle.value, 2);
      await resource.close();
    },
  );

  test(
    'family close aggregates drain, cancellation, observation and close failures',
    () async {
      final cancel = StateError('cancel');
      final drain = StateError('drain');
      final close = StateError('close');
      final observation = StateError('observation');
      final producer = Producer(1)
        ..cancelError = cancel
        ..drainError = drain
        ..closeError = close;
      final resource = LxResource<int, Producer>(() => producer);
      final handle = resource;
      handle.value;
      LevitReactiveMiddleware.add(
        DisposeHook((next, reactive) {
          next();
          if (reactive.id == handle.id) throw observation;
        }),
      );
      await expectLater(
        resource.close(),
        throwsA(failures([cancel, drain, close, observation])),
      );
      expect(handle.isClosed, isTrue);
      expect(resource.isDisposed, isTrue);
    },
  );

  test(
    'close waits for a failed in-flight refresh and preserves its failure',
    () async {
      final gate = Completer<void>();
      final error = StateError('refresh cleanup');
      final resource = LxResource<int, Producer>(() => Producer(1));
      resource.producer
        ..gate = gate
        ..closeError = error;
      final refresh = expectLater(
        resource.refresh(),
        throwsA(failures([error])),
      );
      final close = expectLater(resource.close(), throwsA(failures([error])));
      gate.complete();
      await refresh;
      await close;
    },
  );

  test('family rejects self refresh and closure from owned worker', () async {
    final source = 0.lx;
    final finished = Completer<void>();
    late LxResource<LxWorkerStat, LxWorker<int>> resource;
    resource = LxResource(
      () => LxWorker.withContext(source, (_, _) async {
        expect(() => resource.refresh(), throwsStateError);
        expect(() => resource.close(), throwsStateError);
        await expectLater(resource.drain(), throwsStateError);
        finished.complete();
      }),
    );
    resource.value;
    source.value++;
    await finished.future;
    await resource.close();
    await source.close();
  });
  test(
    'unreadable replacement rejects refresh, closes failed producer, and retries',
    () async {
      var n = 0;
      final error = StateError('replacement first read');
      final broken = Producer(2)..readError = error;
      final res = LxResource<int, Producer>(
        () => ++n == 2 ? broken : Producer(n),
      );
      expect(res.value, 1);
      await expectLater(res.refresh(), throwsA(same(error)));
      expect(broken.isDisposed, true);
      expect(res.lastValue, 1);
      await res.refresh();
      expect(res.value, 3);
      await res.close();
    },
  );
  test(
    'a draining worker cannot join the refresh waiting for its finally',
    () async {
      final source = 0.lx, start = Completer<void>(), check = Completer<void>();
      late final LxResource<LxWorkerStat, LxWorker<int>> res;
      res = LxResource(
        () => LxWorker.withContext(source, (_, _) async {
          start.complete();
          await check.future;
          expect(res.refresh, throwsStateError);
        }),
      );
      res.value;
      source.value++;
      await start.future;
      final refresh = res.refresh();
      check.complete();
      await refresh;
      await res.close();
      await source.close();
    },
  );
  test('close an unused resource without starting it', () async {
    final res = LxResource<int, LxVar<int>>(
      () => throw StateError('must not start'),
    );
    await res.close();
    expect(res.isDisposed, true);
  });
}
