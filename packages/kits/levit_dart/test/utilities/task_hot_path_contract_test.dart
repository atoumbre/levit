import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

void main() {
  test(
    'closing scopes retain self-disposal guards while owned work drains',
    () async {
      final scope = LevitScope.root('draining');
      final engine = scope.put(() => LevitTaskEngine(maxConcurrent: 1));
      final started = Completer<void>();
      final release = Completer<void>();
      var rejected = false;
      final work = engine.submit((_) async {
        started.complete();
        await release.future;
        expect(scope.isClosing, isTrue);
        try {
          scope.assertCanDispose();
        } on StateError {
          rejected = true;
        }
        return 1;
      });
      await started.future;
      final closing = scope.dispose();
      release.complete();
      await work.outcome;
      await closing;
      expect(
        rejected,
        isTrue,
        reason: 'Retiring owned work must still guard its scope.',
      );
    },
  );

  test(
    'late cancellation observation and group task identities stay isolated',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 3);
      final group = LevitTaskGroup(engine: engine);
      final release = Completer<void>();
      final root = engine.submit((_) => release.future, id: 'same');
      final child = group.schedule((_) => release.future, id: 'same');
      final shaped = engine.submit((_) => 7, id: '${group.id}:same');
      expect(await shaped.result, 7);
      expect(engine.runningCount, 2);
      release.complete();
      await root.result;
      await child;
      group.cancel();
      final cancelled = group.cancelled;
      expect(group.cancelled, same(cancelled));
      await cancelled;
      expect(
        group.cancellationReason!.kind,
        LevitTaskCancellationKind.requested,
      );
      await group.dispose();
      await engine.dispose();
    },
  );

  test(
    'late outcome listeners preserve null, failure and cancellation',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final success = engine.submit<int?>((_) => null);
      final error = StateError('failed');
      final failure = engine.submit<int>((_) => throw error);
      final cancelled = engine.submit<int>((_) => 4)..cancel();
      // No result/outcome listeners until after completion. Errors must remain
      // observable later without escaping as uncaught zone errors in the meantime.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((await success.outcome as LevitTaskSuccess<int?>).value, isNull);
      expect(
        (await failure.outcome as LevitTaskFailure<int>).error,
        same(error),
      );
      expect(await cancelled.outcome, isA<LevitTaskCancelled<int>>());
      expect(failure.outcome, same(failure.outcome));
      await expectLater(failure.result, throwsA(same(error)));
      await engine.dispose();
    },
  );

  test(
    'uncached work still starts after admission and observes cancellation',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      var ran = false;
      final work = engine.submit<int>((_) {
        ran = true;
        return 1;
      });
      expect(ran, isFalse);
      work.cancel();
      expect(await work.outcome, isA<LevitTaskCancelled<int>>());
      expect(ran, isFalse);
      await engine.dispose();
    },
  );

  test(
    'nested foreign-engine groups preserve both current group and outer guard',
    () async {
      final outer = LevitTaskEngine(maxConcurrent: 1);
      final inner = LevitTaskEngine(maxConcurrent: 1);
      await outer.schedule((_) async {
        final parent = LevitTaskGroup.current;
        final group = LevitTaskGroup(engine: inner);
        expect(
          await group.run((current) async {
            expect(LevitTaskGroup.current, same(current));
            expect(outer.assertCanDispose, throwsStateError);
            await Future<void>.value();
            expect(LevitTaskGroup.current, same(current));
            expect(outer.assertCanDispose, throwsStateError);
            return current.schedule((context) async {
              expect(LevitTaskGroup.current, same(current));
              expect(inner.assertCanDispose, throwsStateError);
              await Future<void>.value();
              expect(LevitTaskGroup.current, same(current));
              expect(inner.assertCanDispose, throwsStateError);
              return 9;
            });
          }),
          9,
        );
        expect(LevitTaskGroup.current, same(parent));
        expect(outer.assertCanDispose, throwsStateError);
      });
      expect(LevitTaskGroup.current, isNull);
      await outer.dispose();
      await inner.dispose();
    },
  );
}
