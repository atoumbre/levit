import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('LevitTaskEngine instrumentation', () {
    test('emits queued/started/finished lifecycle events', () async {
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final blocker = Completer<void>();

      final first = engine.schedule(
        () async {
          await blocker.future;
          return 'first';
        },
        id: 'first',
        priority: TaskPriority.normal,
      );

      final second = engine.schedule(
        () async => 'second',
        id: 'second',
        priority: TaskPriority.high,
      );

      await Future<void>.delayed(Duration.zero);
      blocker.complete();
      await Future.wait([first, second]);

      final secondQueuedIndex = events.indexWhere((event) =>
          event.taskId == 'second' && event.type == LevitTaskEventType.queued);
      final secondStartedIndex = events.indexWhere((event) =>
          event.taskId == 'second' && event.type == LevitTaskEventType.started);
      final secondFinishedIndex = events.indexWhere((event) =>
          event.taskId == 'second' &&
          event.type == LevitTaskEventType.finished);

      expect(secondQueuedIndex, greaterThanOrEqualTo(0));
      expect(secondStartedIndex, greaterThan(secondQueuedIndex));
      expect(secondFinishedIndex, greaterThan(secondStartedIndex));
    });

    test('emits retryScheduled with attempt and delay metadata', () async {
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      var count = 0;

      final result = await engine.schedule<String>(
        () {
          count++;
          if (count == 1) throw StateError('fail first');
          return 'ok';
        },
        id: 'retry_task',
        retries: 1,
        retryDelay: const Duration(milliseconds: 1),
        useExponentialBackoff: false,
      );

      expect(result, 'ok');
      final retryEvent = events.singleWhere(
        (event) => event.type == LevitTaskEventType.retryScheduled,
      );
      expect(retryEvent.taskId, 'retry_task');
      expect(retryEvent.attempt, 2);
      expect(retryEvent.retryIn, const Duration(milliseconds: 1));
      expect(retryEvent.error, isA<StateError>());
    });

    test('emits skipped(cacheHit) when result is served from cache', () async {
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final policy = TaskCachePolicy<int>(
        ttl: const Duration(minutes: 1),
        toJson: (value) => {'value': value},
        fromJson: (json) => json['value'] as int,
      );

      await engine.schedule<int>(
        () => 10,
        id: 'cached_task',
        cachePolicy: policy,
      );

      final second = await engine.schedule<int>(
        () => 999,
        id: 'cached_task',
        cachePolicy: policy,
      );

      expect(second, 10);
      expect(
        events.any((event) =>
            event.taskId == 'cached_task' &&
            event.type == LevitTaskEventType.skipped &&
            event.skipReason == TaskSkipReason.cacheHit),
        isTrue,
      );
    });

    test('emits skipped(cancelledWhileQueued) for queued cancellations',
        () async {
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final blocker = Completer<void>();

      final active = engine.schedule(
        () async {
          await blocker.future;
          return 'active';
        },
        id: 'active_task',
      );
      final queued = engine.schedule(
        () async => 'queued',
        id: 'queued_task',
      );

      await Future<void>.delayed(Duration.zero);
      engine.cancel('queued_task');
      expect(await queued, isNull);

      blocker.complete();
      await active;

      expect(
        events.any((event) =>
            event.taskId == 'queued_task' &&
            event.type == LevitTaskEventType.skipped &&
            event.skipReason == TaskSkipReason.cancelledWhileQueued),
        isTrue,
      );
    });

    test('emits skipped(cancelledAfterRun) for active cancellation', () async {
      final events = <LevitTaskEvent>[];
      final engine = LevitTaskEngine(
        maxConcurrent: 1,
        onTaskEvent: events.add,
      );
      final blocker = Completer<void>();

      final active = engine.schedule<String>(
        () async {
          await blocker.future;
          return 'done';
        },
        id: 'cancelled_active_task',
      );

      await Future<void>.delayed(Duration.zero);
      engine.cancel('cancelled_active_task');
      blocker.complete();

      expect(await active, isNull);
      expect(
        events.any((event) =>
            event.taskId == 'cancelled_active_task' &&
            event.type == LevitTaskEventType.skipped &&
            event.skipReason == TaskSkipReason.cancelledAfterRun),
        isTrue,
      );
    });
  });
}
