import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

import 'task_group_acceptance_test.dart' show ReactiveTaskOwner;
import 'package:levit_dart/tasks.dart';

void main() {
  test(
    'query refresh creates missing entries and invalidation respects observers',
    () async {
      var generation = 0;
      final query = LevitAsyncMap<int, int>((_, _) => ++generation);
      expect(query.peek(1), isNull);
      await query.refresh(1);
      final handle = query.peek(1)!;
      expect(query.keys, [1]);
      expect(await query.invalidate(2), isFalse);
      void listener() {}
      handle.addListener(listener);
      expect(await query.invalidate(1), isTrue);
      expect(handle.value.lastValue, 2);
      handle.removeListener(listener);
      expect(await query.invalidate(1), isTrue);
      expect(handle.isClosed, isTrue);
      await query.dispose();
      expect(query.isClosing, isTrue);
      expect(query.isDisposed, isTrue);
      await expectLater(query.invalidate(1), throwsStateError);
    },
  );

  test('query resource rejects disposal from its task', () async {
    final gate = Completer<void>();
    late LevitAsyncMap<int, int> query;
    query = LevitAsyncMap((key, _) async {
      await gate.future;
      expect(() => query.evict(key), throwsStateError);
      return key;
    });
    final result = query.fetch(3);
    gate.complete();
    expect(await result, 3);
    await query.drain();
    await query.dispose();
  });

  test(
    'owned query engine drains failing finally blocks and reports cleanup',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final failure = StateError('query finally');
      final query = LevitAsyncMap<int, int>((_, context) async {
        started.complete();
        try {
          await context.cancelled;
          return 1;
        } finally {
          await release.future;
          throw failure;
        }
      });
      final refresh = query.refresh(1);
      final checkedRefresh = expectLater(
        refresh,
        throwsA(isA<LevitTaskCancelledException>()),
      );
      await started.future;
      var closed = false;
      final closing = query.dispose();
      final checkedClose = expectLater(
        closing,
        throwsA(isA<LevitDisposalException>()),
      );
      unawaited(
        closing.then<void>(
          (_) => closed = true,
          onError: (Object _) {
            closed = true;
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      release.complete();
      await checkedRefresh;
      await checkedClose;
      expect(query.isDisposed, isTrue);
    },
  );

  test(
    'query drain waits for refresh settlement without closing borrowed engine',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final gate = Completer<int>();
      final query = LevitAsyncMap<int, int>(
        (_, _) => gate.future,
        engine: engine,
      );
      final refreshing = query.refresh(1);
      var drained = false;
      final draining = query.drain().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      gate.complete(9);
      await draining;
      await refreshing;
      expect(query.entry(1).value.lastValue, 9);
      await query.dispose();
      expect(await engine.schedule((_) => 10), 10);
      await engine.dispose();
    },
  );

  test(
    'typed task selectors retain a successful null while waiting and failing',
    () async {
      final owner = ReactiveTaskOwner();
      final error = StateError('later failure');
      for (final status in <LxStatus<Object?>>[
        LxWaiting<Object?>.retained(null),
        LxError<Object?>.retained(error, null),
      ]) {
        owner.tasks['nullable'] = LevitTaskDetails(status: status);
        final selected = owner.taskStatus<String?>('nullable');
        expect(selected.hasLastValue, isTrue);
        expect(selected.lastValue, isNull);
        if (status is LxError) expect((selected as LxError).error, same(error));
      }
      await owner.onClose();
    },
  );
}
