import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('task conflict policies', () {
    test('reject is the default and emits a rejected execution event',
        () async {
      final blocker = Completer<void>();
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        ownerPath: 'scope:owner',
        onTaskEvent: events.add,
      );
      final active = engine.schedule(
        (_) async {
          await blocker.future;
          return 1;
        },
        id: 'sync',
      );

      expect(
        () => engine.schedule((_) => 2, id: 'sync'),
        throwsA(isA<TaskConflictException>()),
      );
      final rejected = events.singleWhere(
        (event) => event.type == LevitTaskEventType.rejected,
      );
      expect(rejected.outcome, LevitTaskOutcome.rejected);
      expect(rejected.ownerPath, 'scope:owner');
      expect(rejected.executionId, isNot(rejected.taskId));

      blocker.complete();
      expect(await active, 1);
    });

    test('join targets a retained coalesced tail and ignores its callback',
        () async {
      final blocker = Completer<void>();
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final active = engine.schedule(
        (_) async {
          await blocker.future;
          return 1;
        },
        id: 'refresh',
      );
      final tail = engine.submit(
        (_) => 2,
        id: 'refresh',
        conflictPolicy: TaskConflictPolicy.coalesceLatest,
      );
      var joinedCallbackRan = false;
      final joined = engine.submit(
        (_) {
          joinedCallbackRan = true;
          return 3;
        },
        id: 'refresh',
        conflictPolicy: TaskConflictPolicy.join,
      );

      expect(joined.executionId, tail.executionId);
      blocker.complete();
      expect(await active, 1);
      expect(await tail.result, 2);
      expect(await joined.result, 2);
      expect(joinedCallbackRan, isFalse);
    });

    test('drop completes null without invoking submitted work', () async {
      final blocker = Completer<void>();
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final active = engine.schedule(
        (_) => blocker.future,
        id: 'submit',
      );
      var droppedRan = false;

      final dropped = await engine.schedule(
        (_) {
          droppedRan = true;
          return 2;
        },
        id: 'submit',
        conflictPolicy: TaskConflictPolicy.drop,
      );

      expect(dropped, isNull);
      expect(droppedRan, isFalse);
      expect(
        events.any(
          (event) =>
              event.skipReason == TaskSkipReason.dropped &&
              event.outcome == LevitTaskOutcome.dropped,
        ),
        isTrue,
      );
      blocker.complete();
      await active;
    });

    test('drop cancel no-op is safe to invoke', () async {
      final blocker = Completer<void>();
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final active = engine.schedule((_) => blocker.future, id: 'drop-cancel');

      final dropped = engine.submit(
        (_) => 2,
        id: 'drop-cancel',
        conflictPolicy: TaskConflictPolicy.drop,
      );

      expect(dropped.disposition, LevitTaskSubmissionDisposition.dropped);
      dropped.cancel();
      expect(await dropped.result, isNull);

      blocker.complete();
      await active;
    });

    test('restart admits replacement and suppresses stale completion',
        () async {
      final oldGate = Completer<void>();
      final replacementStarted = Completer<void>();
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 2,
        onTaskEvent: events.add,
      );
      final old = engine.schedule(
        (_) async {
          await oldGate.future;
          return 'old';
        },
        id: 'session',
      );
      final replacement = engine.schedule(
        (_) {
          replacementStarted.complete();
          return 'new';
        },
        id: 'session',
        conflictPolicy: TaskConflictPolicy.restart,
      );

      await replacementStarted.future;
      expect(await replacement, 'new');
      oldGate.complete();
      expect(await old, isNull);
      expect(
        events.any(
          (event) =>
              event.taskId == 'session' &&
              event.outcome == LevitTaskOutcome.superseded,
        ),
        isTrue,
      );
    });

    test('enqueue preserves ID FIFO while priority applies across IDs',
        () async {
      final blocker = Completer<void>();
      final order = <String>[];
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final hold = engine.schedule(
        (_) async {
          order.add('hold');
          await blocker.future;
        },
        id: 'hold',
      );
      final firstForId = engine.schedule(
        (_) => order.add('x1'),
        id: 'x',
        priority: TaskPriority.low,
        conflictPolicy: TaskConflictPolicy.enqueue,
      );
      final secondForId = engine.schedule(
        (_) => order.add('x2'),
        id: 'x',
        priority: TaskPriority.high,
        conflictPolicy: TaskConflictPolicy.enqueue,
      );
      final otherId = engine.schedule(
        (_) => order.add('y'),
        id: 'y',
        priority: TaskPriority.normal,
      );

      blocker.complete();
      await Future.wait([hold, firstForId, secondForId, otherId]);
      expect(order, ['hold', 'y', 'x1', 'x2']);
    });

    test('coalesceLatest retains one tail and replaces its configuration',
        () async {
      final blocker = Completer<void>();
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final active = engine.schedule(
        (_) async {
          await blocker.future;
          return 1;
        },
        id: 'media',
      );
      var obsoleteRan = false;
      final firstTail = engine.submit(
        (_) {
          obsoleteRan = true;
          return 2;
        },
        id: 'media',
        conflictPolicy: TaskConflictPolicy.coalesceLatest,
      );
      final latestTail = engine.submit(
        (_) => 3,
        id: 'media',
        priority: TaskPriority.high,
        conflictPolicy: TaskConflictPolicy.coalesceLatest,
      );

      expect(latestTail.executionId, firstTail.executionId);
      expect(
        latestTail.disposition,
        LevitTaskSubmissionDisposition.coalesced,
      );
      blocker.complete();
      expect(await active, 1);
      expect(await firstTail.result, 3);
      expect(await latestTail.result, 3);
      expect(obsoleteRan, isFalse);
      expect(
        events.any((event) => event.type == LevitTaskEventType.coalesced),
        isTrue,
      );
    });
  });

  group('task context and events', () {
    test('reports validated progress and exposes cooperative cancellation',
        () async {
      final progress = <double>[];
      final entered = Completer<void>();
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final execution = engine.submit<String>(
        (context) async {
          expect(context.taskId, 'download');
          expect(context.executionId, isNotEmpty);
          expect(context.attempt, 1);
          context.reportProgress(.25);
          entered.complete();
          await context.cancelled;
          context.throwIfCancelled();
          return 'unreachable';
        },
        id: 'download',
        onProgress: progress.add,
      );

      await entered.future;
      execution.cancel();
      expect(await execution.result, isNull);
      expect(progress, [.25]);
      execution.cancel();
    });

    test('invalid progress fails the task', () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      await expectLater(
        engine.schedule<void>((context) => context.reportProgress(double.nan)),
        throwsRangeError,
      );
    });

    test('retry creates a new attempt context for one execution', () async {
      final attempts = <int>[];
      final executionIds = <String>[];
      final engine = LevitTaskEngine(maxConcurrent: 1);

      final result = await engine.schedule(
        (context) {
          attempts.add(context.attempt);
          executionIds.add(context.executionId);
          if (context.attempt == 1) throw StateError('retry');
          return 'ok';
        },
        retries: 1,
        retryDelay: Duration.zero,
      );

      expect(result, 'ok');
      expect(attempts, [1, 2]);
      expect(executionIds.toSet(), hasLength(1));
    });

    test('events carry metadata, identity, progress, and timing', () async {
      final events = <LevitTaskEvent>[];
      final metadata = LevitTaskMetadata(
        debugName: 'sync-shop',
        category: 'sync',
        blocksUserInteraction: true,
        sensitive: true,
        attributes: const {'source': 'manual'},
      );
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        ownerPath: '7:SyncController',
        onTaskEvent: events.add,
      );

      await engine.schedule(
        (context) {
          context.reportProgress(.5);
          return 42;
        },
        id: 'sync',
        metadata: metadata,
      );

      final queued = events.first;
      final finished = events.last;
      expect(events.map((event) => event.executionId).toSet(), hasLength(1));
      expect(queued.phase, LevitTaskPhase.queued);
      expect(finished.phase, LevitTaskPhase.completed);
      expect(finished.outcome, LevitTaskOutcome.succeeded);
      expect(finished.ownerPath, '7:SyncController');
      expect(finished.metadata, same(metadata));
      expect(finished.queueDuration, isNotNull);
      expect(finished.runDuration, isNotNull);
      expect(
        events
            .singleWhere(
              (event) => event.type == LevitTaskEventType.progress,
            )
            .progress,
        .5,
      );
    });
  });
}
