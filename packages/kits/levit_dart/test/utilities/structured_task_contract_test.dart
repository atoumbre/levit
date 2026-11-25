import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  test(
    'single-slot nested groups coordinate without consuming slots',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final result = await engine.rootGroup.runGroup((group) async {
        final first = group.runGroup(
          (child) => child.schedule((_) async => 10),
        );
        final second = group.runGroup(
          (child) => child.schedule((_) async => 20),
        );
        return (await first) + (await second);
      });
      expect(result, 30);
      expect(engine.runningCount, 0);
      await engine.dispose();
    },
  );

  test(
    'group completion drains descendant finally after cancellation',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 2);
      final group = LevitTaskGroup(engine: engine);
      final started = Completer<void>();
      final release = Completer<void>();
      final events = <String>[];
      final result = group.run((g) async {
        g.submit((context) async {
          started.complete();
          try {
            await context.cancelled;
          } finally {
            await release.future;
            events.add('finally');
          }
        });
      });
      final observed = expectLater(
        result,
        throwsA(isA<LevitTaskCancelledException>()),
      );
      await started.future;
      group.cancel();
      var closed = false;
      final closing = engine.dispose().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      release.complete();
      await observed;
      await closing;
      expect(events, ['finally']);
    },
  );

  for (final policy in LevitTaskGroupPolicy.values) {
    test('$policy handles failed siblings while root work continues', () async {
      final engine = LevitTaskEngine(maxConcurrent: 3);
      final start = Completer<void>();
      final fail = Completer<void>();
      var siblingCancelled = false;
      final group = LevitTaskGroup(engine: engine, policy: policy);
      final workflow = group.run((g) {
        g.submit((_) async {
          await fail.future;
          throw StateError('upload');
        });
        g.submit((ctx) async {
          start.complete();
          await fail.future;
          if (policy == LevitTaskGroupPolicy.cancelOnError) await ctx.cancelled;
          siblingCancelled = ctx.isCancelled;
          return 1;
        });
      });
      final observed = expectLater(
        workflow,
        throwsA(isA<LevitTaskGroupException>()),
      );
      await start.future;
      fail.complete();
      expect(await engine.schedule((_) => 99), 99);
      await observed;
      expect(siblingCancelled, policy == LevitTaskGroupPolicy.cancelOnError);
      expect(engine.rootGroup.isCancelled, isFalse);
      await engine.dispose();
    });
  }

  test(
    'pending deadline includes queue time and never starts expired work',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final blocker = Completer<void>();
      final running = engine.submit((_) => blocker.future);
      var invoked = false;
      final queued = engine.submit((_) {
        invoked = true;
        return 1;
      }, deadline: DateTime.now().add(const Duration(milliseconds: 10)));
      final outcome = await queued.outcome;
      expect(outcome, isA<LevitTaskCancellation<int>>());
      expect(
        (outcome as LevitTaskCancellation<int>).reason.kind,
        LevitCancellationKind.deadlineExceeded,
      );
      expect(invoked, isFalse);
      blocker.complete();
      await running.result;
      await engine.dispose();
    },
  );

  test('earliest deadline is inherited by descendants', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final limit = DateTime.now().add(const Duration(seconds: 1));
    await engine.rootGroup.runGroup(
      (g) => g.runGroup(
        (child) => child.schedule((ctx) {
          expect(ctx.deadline, limit);
          return 1;
        }, deadline: limit.add(const Duration(hours: 1))),
      ),
      deadline: limit,
    );
    await engine.dispose();
  });

  test('queue saturation preserves joins and pending coalescing', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1, maxPending: 1);
    final release = Completer<void>();
    final active = engine.submit((_) => release.future, id: 'active');
    final queued = engine.submit((_) => 1, id: 'next');
    final joined = engine.submit(
      (_) => 2,
      id: 'next',
      conflictPolicy: TaskConflictPolicy.join,
    );
    expect(joined.executionId, queued.executionId);
    expect(
      () => engine.submit((_) => 3, id: 'overflow'),
      throwsA(isA<LevitTaskQueueFullException>()),
    );
    final dropped = engine.submit(
      (_) => 4,
      id: 'next',
      conflictPolicy: TaskConflictPolicy.drop,
    );
    expect(await dropped.outcome, isA<LevitTaskDropping<int>>());
    release.complete();
    await active.result;
    expect(await joined.result, 1);
    await engine.dispose();
  });

  test(
    'weighted priority scheduling prevents low-priority starvation and preserves FIFO',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final release = Completer<void>();
      final first = engine.submit((_) => release.future);
      final order = <String>[];
      final results = <LevitTaskExecution<void>>[];
      for (var i = 0; i < 20; i++) {
        results.add(
          engine.submit((_) {
            order.add('h$i');
          }, priority: TaskPriority.high),
        );
      }
      results.add(
        engine.submit((_) {
          order.add('low');
        }, priority: TaskPriority.low),
      );
      release.complete();
      await first.result;
      await Future.wait(results.map((task) => task.result));
      expect(order.indexOf('low'), lessThan(8));
      expect(
        order.where((entry) => entry != 'low'),
        List.generate(20, (i) => 'h$i'),
      );
      await engine.dispose();
    },
  );

  test(
    'successful null, supersession and cancellation are distinct outcomes',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final successful = engine.submit<int?>((_) => null);
      expect(await successful.result, isNull);
      expect(await successful.outcome, isA<LevitTaskSuccess<int?>>());
      final started = Completer<void>();
      final first = engine.submit((ctx) async {
        started.complete();
        await ctx.cancelled;
        return 1;
      }, id: 'same');
      await started.future;
      final second = engine.submit(
        (_) => 2,
        id: 'same',
        conflictPolicy: TaskConflictPolicy.restart,
      );
      expect(await first.outcome, isA<LevitTaskSupersession<int>>());
      expect(await second.result, 2);
      await engine.dispose();
    },
  );

  test(
    'retry classifiers and caps are explicit; cancellation never retries',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      var calls = 0;
      final retry = LevitRetryPolicy(
        shouldRetry: (error, _) => error is FormatException,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        maxRetries: 2,
      );
      expect(
        await engine.schedule((_) {
          if (++calls < 3) throw const FormatException();
          return 7;
        }, retryPolicy: retry),
        7,
      );
      final permanent = engine.submit(
        (_) => throw StateError('permanent'),
        retryPolicy: retry,
      );
      expect(await permanent.outcome, isA<LevitTaskFailure>());
      var attempts = 0;
      final cancelled = engine.submit((ctx) async {
        attempts++;
        await ctx.cancelled;
        ctx.throwIfCancelled();
      }, retryPolicy: retry);
      await Future<void>.delayed(Duration.zero);
      cancelled.cancel();
      expect(await cancelled.outcome, isA<LevitTaskCancellation>());
      expect(attempts, 1);
      final capped = LevitRetryPolicy(
        shouldRetry: (_, __) => true,
        initialDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 5),
      );
      expect(capped.delayFor(1000, randomValue: 1), const Duration(seconds: 5));
      await engine.dispose();
    },
  );

  test('task tree is reactive and owner self-disposal is rejected', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final snapshots = <LevitTaskTreeSnapshot>[];
    engine.taskTree.addListener(() => snapshots.add(engine.taskTree.value));
    await engine.schedule((_) async {
      expect(() => engine.dispose(), throwsStateError);
      expect(engine.runningCount, 1);
    });
    expect(snapshots.any((tree) => tree.runningCount == 1), isTrue);
    await engine.dispose();
  });
  test(
    'replacing a coalesced pending tail does not consume queue capacity',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1, maxPending: 1);
      final gate = Completer<void>();
      final active = engine.submit((_) => gate.future, id: 'upload');
      final tail = engine.submit(
        (_) => 1,
        id: 'upload',
        conflictPolicy: TaskConflictPolicy.coalesceLatest,
      );
      final latest = engine.submit(
        (_) => 2,
        id: 'upload',
        conflictPolicy: TaskConflictPolicy.coalesceLatest,
      );
      expect(engine.pendingCount, 1);
      expect(latest.executionId, tail.executionId);
      gate.complete();
      await active.result;
      expect(await tail.result, 2);
      await engine.dispose();
    },
  );

  test(
    'expired submissions never enter their task even with a free slot',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      var called = false;
      final task = engine.submit((_) {
        called = true;
        return 1;
      }, deadline: DateTime.now().subtract(const Duration(seconds: 1)));
      expect(await task.outcome, isA<LevitTaskCancellation<int>>());
      expect(called, isFalse);
      await engine.dispose();
    },
  );

  test(
    'owner cleanup propagates failing finally after draining siblings',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 2);
      final started = Completer<void>();
      final otherStarted = Completer<void>();
      final release = Completer<void>();
      engine.submit((ctx) async {
        started.complete();
        try {
          await ctx.cancelled;
        } finally {
          throw StateError('cleanup failed');
        }
      });
      engine.submit((ctx) async {
        otherStarted.complete();
        try {
          await ctx.cancelled;
        } finally {
          await release.future;
        }
      });
      await Future.wait([started.future, otherStarted.future]);
      var completed = false;
      final closing = engine.dispose();
      final checked = expectLater(
        closing,
        throwsA(isA<LevitDisposalException>()),
      ).then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      release.complete();
      await checked;
    },
  );

  test(
    'group cancellation reaches isolate context and awaits its final message',
    () async {
      final started = Completer<void>();
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: (event) {
          if (event.type == LevitTaskEventType.progress && !started.isCompleted)
            started.complete();
        },
      );
      final group = LevitTaskGroup(engine: engine);
      late LevitTaskExecution<int> task;
      final workflow = group.run((g) {
        task = engine.submitIsolate(_waitInIsolate, 7, group: g);
      });
      final observed = expectLater(
        workflow,
        throwsA(isA<LevitTaskCancelledException>()),
      );
      await started.future;
      group.cancel(
        const LevitTaskCancellationReason(
          LevitCancellationKind.parentCancelled,
        ),
      );
      final outcome = await task.outcome;
      expect(
        (outcome as LevitTaskCancellation<int>).reason.kind,
        LevitCancellationKind.parentCancelled,
      );
      await observed;
      await engine.dispose();
    },
  );
}

Future<int> _waitInIsolate(int value, LevitIsolateTaskContext context) async {
  context.reportProgress(0.5);
  await context.cancelled;
  if (context.cancellationReason?.kind !=
      LevitCancellationKind.parentCancelled) {
    throw StateError('Wrong cancellation reason in isolate');
  }
  await Future<void>.delayed(const Duration(milliseconds: 5));
  context.throwIfCancelled();
  return value;
}
