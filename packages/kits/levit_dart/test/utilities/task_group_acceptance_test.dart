import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

class TaskOwner extends LevitController with LevitTasksMixin {}

class ReactiveTaskOwner extends LevitController with LevitReactiveTasksMixin {}

class DelayedCache implements LevitTaskCacheProvider {
  final _inner = LevitTaskCacheProvider.inMemory();
  final writing = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    writing.complete();
    await release.future;
    await _inner.write(key, data);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) => _inner.read(key);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}

class FailingService implements LevitLoopService {
  FailingService(this.error, this.gate);
  final Object error;
  final Completer<void> gate;
  @override
  final status = LxVar<LxStatus<dynamic>>(LxIdle());
  @override
  void start() {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  Future<void> stop() async {
    await gate.future;
    await status.close();
    throw error;
  }
}

void main() {
  test(
    'cancellation during cache IO waits for the write and suppresses success',
    () async {
      final cache = DelayedCache();
      final engine = LevitTaskEngine(maxConcurrent: 1, cacheProvider: cache);
      var published = false;
      final task = engine.submit(
        (_) => 3,
        onSuccess: (_) => published = true,
        cachePolicy: LevitTaskCachePolicy<int>(
          ttl: const Duration(minutes: 1),
          toJson: (value) => {'value': value},
          fromJson: (json) => json['value'] as int,
        ),
      );
      await cache.writing.future;
      task.cancel();
      var closed = false;
      final closing = engine.dispose().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      cache.release.complete();
      expect(await task.outcome, isA<LevitTaskCancelled<int>>());
      await closing;
      expect(published, isFalse);
    },
  );
  test(
    'controller roots supervise and implicit submissions belong to the current group',
    () async {
      final owner = TaskOwner();
      final reactive = ReactiveTaskOwner();
      expect(owner.taskGroup.policy, LevitTaskGroupPolicy.supervisor);
      expect(reactive.taskGroup.policy, LevitTaskGroupPolicy.supervisor);
      await owner.taskGroup.runGroup((group) async {
        expect(
          await owner.taskEngine.schedule((ctx) {
            expect(ctx.group, same(group));
            return 7;
          }),
          7,
        );
      });
      await owner.onClose();
      await reactive.onClose();
    },
  );

  test(
    'invalid queue, retry and cross-engine group configurations fail before admission',
    () async {
      expect(
        () => LevitTaskEngine(maxConcurrent: 1, maxPending: 0),
        throwsRangeError,
      );
      for (final jitter in [-0.1, 1.1, double.nan, double.infinity]) {
        expect(
          () => LevitRetryPolicy(shouldRetry: (_, _) => true, jitter: jitter),
          throwsRangeError,
        );
      }
      final first = LevitTaskEngine(maxConcurrent: 1);
      final second = LevitTaskEngine(maxConcurrent: 1);
      expect(
        () => LevitTaskGroup(engine: first, parent: second.rootGroup),
        throwsArgumentError,
      );
      expect(
        () => first.submit((_) => 1, group: second.rootGroup),
        throwsArgumentError,
      );
      await expectLater(first.rootGroup.run((_) {}), throwsStateError);
      expect(
        const LevitTaskQueueFullException(256).toString(),
        contains('256'),
      );
      expect(
        const LevitTaskCancellationReason(
          LevitTaskCancellationKind.requested,
        ).toString(),
        'requested',
      );
      expect(
        const LevitTaskCancellationReason(
          LevitTaskCancellationKind.requested,
          'user',
        ).toString(),
        'requested: user',
      );
      expect(
        const LevitTaskCancelledException('task', 'execution').toString(),
        contains('execution'),
      );
      await first.dispose();
      await second.dispose();
    },
  );

  test(
    'group deadline cancels its body and descendants and retains its reason',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final group = LevitTaskGroup(
        engine: engine,
        deadline: DateTime.now().add(const Duration(milliseconds: 30)),
      );
      final result = group.run((g) async {
        final task = g.submit((context) async {
          await context.cancelled;
          expect(
            context.cancellationReason?.kind,
            LevitTaskCancellationKind.deadlineExceeded,
          );
          context.throwIfCancelled();
        });
        await g.cancelled;
        await task.outcome;
      });
      await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
      expect(
        group.cancellationReason?.kind,
        LevitTaskCancellationKind.deadlineExceeded,
      );
      await group.drain();
      await group.dispose();
      await engine.dispose();
    },
  );

  test(
    'expired groups reject admission synchronously before their timer runs',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final expired = LevitTaskGroup(engine: engine, deadline: DateTime(2000));
      expect(
        () => expired.submit((_) {}),
        throwsA(isA<LevitTaskCancelledException>()),
      );
      expect(() => expired.submit((_) {}), throwsStateError);
      await expired.dispose();
      await engine.dispose();
    },
  );

  test(
    'body cancellation preserves its reason; ordinary body failures are aggregated',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      const reason = LevitTaskCancellationReason(
        LevitTaskCancellationKind.parentCancelled,
      );
      final cancelled = LevitTaskGroup(engine: engine);
      await expectLater(
        cancelled.run(
          (_) =>
              throw const LevitTaskCancelledException(
                'task',
                'run',
                reason: reason,
              ),
        ),
        throwsA(
          isA<LevitTaskCancelledException>().having(
            (e) => e.reason,
            'reason',
            same(reason),
          ),
        ),
      );
      final failed = LevitTaskGroup(engine: engine);
      final error = StateError('body');
      final match = isA<LevitTaskGroupException>().having(
        (e) => e.failures.single.error,
        'failure',
        same(error),
      );
      await expectLater(failed.run((_) => throw error), throwsA(match));
      await expectLater(failed.dispose(), throwsA(match));
      expect(
        LevitTaskGroupException([AsyncError(error, null)]).toString(),
        contains('body'),
      );
      await engine.dispose();
    },
  );

  test(
    'unused children seal and nested failures cancel sibling workflows',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      late LevitTaskGroup unused;
      final result = engine.rootGroup.runGroup((parent) async {
        unused = LevitTaskGroup(engine: engine, parent: parent);
        final failed = parent.runGroup((_) => throw StateError('child'));
        await expectLater(failed, throwsA(isA<LevitTaskGroupException>()));
      });
      await expectLater(result, throwsA(isA<LevitTaskGroupException>()));
      expect(unused.isComplete, isTrue);
      await engine.rootGroup.runGroup((parent) {
        unused = LevitTaskGroup(engine: engine, parent: parent);
      });
      expect(unused.isComplete, isTrue);
      await engine.dispose();
    },
  );

  test(
    'self-disposal and group coordination from a leaf fail without deadlocking',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      await engine.rootGroup.runGroup((parent) async {
        await expectLater(parent.run((_) {}), throwsStateError);
        await expectLater(parent.dispose(), throwsStateError);
        await parent.schedule((_) async {
          final child = LevitTaskGroup(engine: engine, parent: parent);
          await expectLater(child.run((_) {}), throwsStateError);
          await expectLater(child.dispose(), throwsStateError);
        });
        late Zone completedChildZone;
        await parent.runGroup((_) {
          completedChildZone = Zone.current;
        });
        await completedChildZone.run(
          () => expectLater(parent.dispose(), throwsStateError),
        );
      });
      final standalone = LevitTaskGroup(engine: engine);
      standalone.assertCanDispose();
      standalone.requestCancel();
      await standalone.drain();
      await standalone.dispose();
      await engine.dispose();
    },
  );

  test(
    'cancelAll cancels child groups while leaving the root reusable',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final group = LevitTaskGroup(engine: engine);
      final work = group.run((g) => g.cancelled);
      final checked = expectLater(
        work,
        throwsA(isA<LevitTaskCancelledException>()),
      );
      engine.cancelAll();
      await checked;
      expect(await engine.schedule((_) => 42), 42);
      await engine.dispose();
    },
  );

  test(
    'loop stop attempts every service and waits before reporting all errors',
    () async {
      final engine = LevitLoopEngine();
      await engine.stopService('absent');
      final first = StateError('first');
      final second = StateError('second');
      final gate = Completer<void>();
      engine.registerService(
        'first',
        FailingService(first, Completer()..complete()),
      );
      engine.registerService('second', FailingService(second, gate));
      var settled = false;
      final stopped = engine.stopAllServices();
      final checked = expectLater(
        stopped,
        throwsA(
          isA<LevitDisposalException>().having(
            (e) => e.failures.map((f) => f.error),
            'errors',
            unorderedEquals([first, second]),
          ),
        ),
      );
      unawaited(
        stopped.then<void>(
          (_) => settled = true,
          onError: (Object _) {
            settled = true;
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      gate.complete();
      await checked;
      await engine.dispose();
    },
  );
}
