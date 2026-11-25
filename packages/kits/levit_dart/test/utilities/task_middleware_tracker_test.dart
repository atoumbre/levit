import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

class _RecordingTaskMiddleware extends LevitTaskMiddleware {
  final events = <LevitTaskEvent>[];

  @override
  void onTaskEvent(LevitTaskEvent event) => events.add(event);
}

class _ThrowingTaskMiddleware extends LevitTaskMiddleware {
  @override
  void onTaskEvent(LevitTaskEvent event) => throw StateError('observer');
}

void main() {
  test('removing an instance clears its tokens and preserves others', () async {
    final removed = _RecordingTaskMiddleware();
    final retained = _RecordingTaskMiddleware();
    final token = Object();
    final alias = Object();
    final retainedToken = Object();
    addTearDown(() {
      LevitTaskMiddleware.remove(removed);
      LevitTaskMiddleware.remove(retained);
      LevitTaskMiddleware.removeByToken(token);
      LevitTaskMiddleware.removeByToken(alias);
      LevitTaskMiddleware.removeByToken(retainedToken);
    });
    final engine = LevitTaskEngine(maxConcurrent: 1);
    addTearDown(engine.dispose);

    LevitTaskMiddleware.add(removed, token: token);
    LevitTaskMiddleware.add(removed, token: alias);
    LevitTaskMiddleware.add(retained, token: retainedToken);
    expect(LevitTaskMiddleware.remove(removed), isTrue);
    expect(LevitTaskMiddleware.contains(removed), isFalse);
    expect(await engine.schedule((_) => 42), 42);
    expect(removed.events, isEmpty);
    expect(retained.events, isNotEmpty);

    // Old tokens must not remove a later registration of the same instance.
    LevitTaskMiddleware.add(removed);
    expect(LevitTaskMiddleware.removeByToken(token), isFalse);
    expect(LevitTaskMiddleware.removeByToken(alias), isFalse);
    expect(LevitTaskMiddleware.contains(removed), isTrue);
    expect(LevitTaskMiddleware.removeByToken(retainedToken), isTrue);
    expect(LevitTaskMiddleware.contains(retained), isFalse);
  });

  test('global middleware is tokenized and failures are isolated', () async {
    final first = _RecordingTaskMiddleware();
    final replacement = _RecordingTaskMiddleware();
    final throwing = _ThrowingTaskMiddleware();
    addTearDown(() {
      LevitTaskMiddleware.remove(first);
      LevitTaskMiddleware.remove(replacement);
      LevitTaskMiddleware.remove(throwing);
    });

    expect(LevitTaskMiddleware.add(first, token: 'monitor'), same(first));
    LevitTaskMiddleware.add(throwing);
    LevitTaskMiddleware.add(replacement, token: 'monitor');
    expect(LevitTaskMiddleware.contains(first), isFalse);
    expect(LevitTaskMiddleware.contains(replacement), isTrue);

    final result = await LevitTaskEngine(maxConcurrent: 1).schedule((_) => 42);
    expect(result, 42);
    expect(first.events, isEmpty);
    expect(replacement.events, isNotEmpty);
    expect(LevitTaskMiddleware.removeByToken('monitor'), isTrue);
    expect(LevitTaskMiddleware.removeByToken('monitor'), isFalse);
    expect(LevitTaskMiddleware.remove(throwing), isTrue);
    expect(LevitTaskMiddleware.remove(throwing), isFalse);
  });

  test(
    'tracker exposes reactive blocking summaries and bounded history',
    () async {
      final tracker = LevitTaskTracker(maxHistory: 1)..attach();
      addTearDown(tracker.dispose);
      final blocker = Completer<void>();
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final active = engine.submit(
        (_) async {
          await blocker.future;
          return 'done';
        },
        id: 'blocking',
        metadata: const LevitTaskMetadata(
          category: 'foreground',
          blocksUserInteraction: true,
        ),
      );

      expect(tracker.hasBlockingTasks.value, isTrue);
      expect(
        tracker.executions[active.executionId]?.metadata.category,
        'foreground',
      );
      blocker.complete();
      await active.result;
      expect(tracker.hasBlockingTasks.value, isFalse);
      expect(
        tracker.executions[active.executionId]?.outcome,
        LevitTaskOutcome.succeeded,
      );

      await engine.schedule((_) => 2, id: 'second');
      expect(tracker.executions, hasLength(1));
      tracker.dispose();
      expect(LevitTaskMiddleware.contains(tracker), isFalse);
      expect(() => tracker.attach(), throwsStateError);
    },
  );

  test('tracker validates history size', () {
    expect(() => LevitTaskTracker(maxHistory: -1), throwsRangeError);
  });
}
