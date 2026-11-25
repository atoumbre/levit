import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

void main() {
  test(
    'pending counts remain exact through replacement, cancellation and drain',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1, maxPending: 3);
      final release = Completer<void>();
      final active = engine.submit((_) => release.future, id: 'active');
      final queued = engine.submit((_) => 1, id: 'queued');
      final joined = engine.submit(
        (_) => 2,
        id: 'queued',
        conflictPolicy: LevitTaskConflictPolicy.join,
      );
      final tail = engine.submit(
        (_) => 3,
        id: 'active',
        conflictPolicy: LevitTaskConflictPolicy.coalesceLatest,
      );
      final replacement = engine.submit(
        (_) => 4,
        id: 'active',
        conflictPolicy: LevitTaskConflictPolicy.coalesceLatest,
      );
      expect(engine.pendingCount, 2);
      expect(tail.executionId, replacement.executionId);
      queued.cancel();
      expect(engine.pendingCount, 1);
      expect(await joined.outcome, isA<LevitTaskCancelled<int>>());
      final restarted = engine.submit(
        (_) => 5,
        id: 'active',
        conflictPolicy: LevitTaskConflictPolicy.restart,
      );
      expect(engine.pendingCount, 1);
      expect(await tail.outcome, isA<LevitTaskSuperseded<int>>());
      release.complete();
      await active.outcome;
      expect(await restarted.result, 5);
      expect(engine.pendingCount, 0);
      final secondRelease = Completer<void>();
      final second = engine.submit((_) => secondRelease.future);
      final remaining = engine.submit((_) => 6);
      expect(engine.pendingCount, 1);
      final closing = engine.dispose();
      expect(engine.pendingCount, 0);
      expect(await remaining.outcome, isA<LevitTaskCancelled<int>>());
      secondRelease.complete();
      await second.outcome;
      await closing;
      expect(engine.pendingCount, 0);
      expect(engine.runningCount, 0);
    },
  );
}
