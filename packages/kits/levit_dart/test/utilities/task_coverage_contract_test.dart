import 'dart:async';
import 'dart:isolate';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

List<bool> _inspectIsolateContext(
  Object? input,
  LevitIsolateTaskContext context,
) {
  var invalidProgressRejected = false;
  try {
    context.reportProgress(double.infinity);
  } on RangeError {
    invalidProgressRejected = true;
  }
  return <bool>[context.isCancelled, invalidProgressRejected];
}

int _doubleInIsolate(int input, LevitIsolateTaskContext context) {
  context.reportProgress(.5);
  return input * 2;
}

Future<String> _delayedIsolate(
  int milliseconds,
  LevitIsolateTaskContext context,
) async {
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
  return 'done';
}

Never _throwInIsolate(Object? input, LevitIsolateTaskContext context) {
  throw StateError('isolate failure');
}

Future<void> _waitForIsolateCancellation(
  Object? input,
  LevitIsolateTaskContext context,
) async {
  await context.cancelled;
  context.throwIfCancelled();
}

Never _exitWithoutResult(Object? input, LevitIsolateTaskContext context) {
  Isolate.exit();
}

Future<void> _crashWithoutTaskResult(
  Object? input,
  LevitIsolateTaskContext context,
) async {
  unawaited(Future<void>.microtask(() => throw StateError('isolate crash')));
  await Completer<void>().future;
}

final class _ThrowingReadCache extends LevitTaskCacheProvider {
  _ThrowingReadCache([this.gate]);

  final Completer<void>? gate;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    await gate?.future;
    throw StateError('cache read');
  }

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {}
}

final class _BasicController extends LevitController with LevitTasksMixin {}

final class _ReactiveController extends LevitController
    with LevitReactiveTasksMixin {}

TaskCachePolicy<int> get _cachePolicy => TaskCachePolicy<int>(
      ttl: const Duration(minutes: 1),
      toJson: (value) => <String, dynamic>{'value': value},
      fromJson: (json) => json['value'] as int,
    );

void main() {
  test('engine validates configuration and compatibility event accessors', () {
    expect(() => LevitTaskEngine(maxConcurrent: 0), throwsRangeError);
    final engine = LevitTaskEngine(maxConcurrent: 1);
    expect(engine.maxConcurrent, 1);
    expect(() => engine.maxConcurrent = 0, throwsRangeError);

    final event = LevitTaskEvent(
      type: LevitTaskEventType.started,
      taskId: 'task',
      debugName: 'compatibility',
      runInIsolate: true,
    );
    expect(event.debugName, 'compatibility');
    expect(event.runInIsolate, isTrue);
    expect(TaskConflictException('task').toString(), contains('"task"'));
  });

  test('submission validates retry settings and progress', () {
    final engine = LevitTaskEngine(maxConcurrent: 1);

    expect(
      () => engine.submit(
        (_) => 1,
        retryDelay: const Duration(microseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.submitIsolate(
        _doubleInIsolate,
        1,
        retryDelay: const Duration(microseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(() => engine.updateProgress('task', double.nan), throwsRangeError);
  });

  test('isolate context exposes state and validates progress', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final result = await engine.scheduleIsolate(
      _inspectIsolateContext,
      null,
    );

    expect(result, <bool>[false, true]);
  });

  test('cache read failures use outer error and cancellation paths', () async {
    final failing = LevitTaskEngine(
      maxConcurrent: 1,
      cacheProvider: _ThrowingReadCache(),
    );
    await expectLater(
      failing.schedule((_) => 1, cachePolicy: _cachePolicy),
      throwsA(isA<StateError>()),
    );

    final gate = Completer<void>();
    final cancelled = LevitTaskEngine(
      maxConcurrent: 1,
      cacheProvider: _ThrowingReadCache(gate),
    );
    final execution = cancelled.submit(
      (_) => 1,
      id: 'cancel-cache',
      cachePolicy: _cachePolicy,
    );
    await Future<void>.delayed(Duration.zero);
    execution.cancel();
    gate.complete();

    expect(await execution.result, isNull);
  });

  test('cancelling a coalesced tail clears its group reference', () async {
    final blocker = Completer<void>();
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final active = engine.schedule(
      (_) => blocker.future,
      id: 'coalesced-cancel',
    );
    final tail = engine.submit(
      (_) => 2,
      id: 'coalesced-cancel',
      conflictPolicy: TaskConflictPolicy.coalesceLatest,
    );

    tail.cancel();
    expect(await tail.result, isNull);
    blocker.complete();
    await active;
  });

  test('schedule captures a replaced coalesced execution', () async {
    final blocker = Completer<void>();
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final active = engine.schedule(
      (_) => blocker.future,
      id: 'coalesced-schedule',
    );
    final firstTail = engine.schedule(
      (_) => 1,
      id: 'coalesced-schedule',
      conflictPolicy: TaskConflictPolicy.coalesceLatest,
    );
    final latestTail = engine.schedule(
      (_) => 2,
      id: 'coalesced-schedule',
      conflictPolicy: TaskConflictPolicy.coalesceLatest,
    );

    blocker.complete();
    await active;
    expect(await firstTail, 2);
    expect(await latestTail, 2);
  });

  test('isolate submission captures a replaced coalesced execution', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final active = engine.submitIsolate(
      _delayedIsolate,
      25,
      id: 'coalesced-isolate',
    );
    final firstTail = engine.submitIsolate(
      _delayedIsolate,
      1,
      id: 'coalesced-isolate',
      conflictPolicy: TaskConflictPolicy.coalesceLatest,
    );
    final latestTail = engine.submitIsolate(
      _delayedIsolate,
      1,
      id: 'coalesced-isolate',
      conflictPolicy: TaskConflictPolicy.coalesceLatest,
    );

    expect(latestTail.executionId, firstTail.executionId);
    expect(await active.result, 'done');
    expect(await firstTail.result, 'done');
    expect(await latestTail.result, 'done');
  });

  test('isolate exit and fatal error ports complete task failures', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);

    await expectLater(
      engine.scheduleIsolate(_exitWithoutResult, null),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      engine.scheduleIsolate(_crashWithoutTaskResult, null),
      throwsA(isA<RemoteError>()),
    );
  });

  test('non-reactive mixin delegates normal and isolate work', () async {
    await Levit.runInScope<void>(() async {
      final controller = Levit.put(() => _BasicController());

      expect(
        await controller.runTask((_) => 4, debugName: 'normal'),
        4,
      );
      expect(
        await controller.runIsolateTask(_doubleInIsolate, 3),
        6,
      );
    }, name: 'basic_task_delegate');
  });

  test('reactive mixin covers validation, errors, progress, and conflicts',
      () async {
    await Levit.runInScope<void>(() async {
      final controller = Levit.put(() => _ReactiveController());

      expect(
        () => controller.runTask((_) => 1, weight: double.nan),
        throwsRangeError,
      );
      expect(
        () => controller.runIsolateTask(
          _doubleInIsolate,
          1,
          weight: double.infinity,
        ),
        throwsRangeError,
      );

      await expectLater(
        controller.runTask<int>(
          (_) => throw StateError('failed'),
          id: 'failed',
          debugName: 'failure',
        ),
        throwsA(isA<StateError>()),
      );
      expect(controller.taskStatus<int>('failed'), isA<LxError<int>>());

      final normalGate = Completer<void>();
      final normalFirst = controller.runTask(
        (_) async {
          await normalGate.future;
          return 'normal';
        },
        id: 'normal-conflict',
      );
      final normalJoined = controller.runTask(
        (_) => 'ignored',
        id: 'normal-conflict',
        conflictPolicy: TaskConflictPolicy.join,
      );
      final normalDropped = controller.runTask(
        (_) => 'ignored',
        id: 'normal-conflict',
        conflictPolicy: TaskConflictPolicy.drop,
      );
      normalGate.complete();
      expect(await normalJoined, 'normal');
      expect(await normalDropped, isNull);
      expect(await normalFirst, 'normal');

      final progressResult = await controller.runIsolateTask(
        _doubleInIsolate,
        4,
        id: 'progress',
        debugName: 'isolate progress',
      );
      expect(progressResult, 8);
      expect(controller.taskProgress('progress'), 1);

      final isolateErrors = <Object>[];
      await expectLater(
        controller.runIsolateTask(
          _throwInIsolate,
          null,
          id: 'isolate-error',
          onError: (error, _) => isolateErrors.add(error),
        ),
        throwsA(isA<RemoteError>()),
      );
      expect(
        controller.taskStatus<Object?>('isolate-error'),
        isA<LxError<Object?>>(),
      );
      expect(isolateErrors.single, isA<RemoteError>());

      final cancellation = controller.runIsolateTask(
        _waitForIsolateCancellation,
        null,
        id: 'isolate-cancel',
      );
      await Future<void>.delayed(Duration.zero);
      controller.cancelTask('isolate-cancel');
      await cancellation;
      expect(
          controller.taskStatus<void>('isolate-cancel'), isA<LxIdle<void>>());

      final first = controller.runIsolateTask(
        _delayedIsolate,
        25,
        id: 'isolate-conflict',
      );
      final joined = controller.runIsolateTask(
        _delayedIsolate,
        1,
        id: 'isolate-conflict',
        conflictPolicy: TaskConflictPolicy.join,
      );
      final dropped = controller.runIsolateTask(
        _delayedIsolate,
        1,
        id: 'isolate-conflict',
        conflictPolicy: TaskConflictPolicy.drop,
      );
      expect(await joined, 'done');
      expect(await dropped, isNull);
      expect(await first, 'done');
    }, name: 'reactive_task_contracts');
  });
}
