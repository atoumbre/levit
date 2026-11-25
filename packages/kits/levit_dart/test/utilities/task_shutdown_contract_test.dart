import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

class Owner extends LevitController with LevitReactiveTasksMixin {}

class PlainOwner extends LevitController with LevitTasksMixin {}

class TimeFirstOwner extends LevitController
    with LevitTimeMixin, LevitReactiveTasksMixin {}

class TasksFirstOwner extends LevitController
    with LevitReactiveTasksMixin, LevitTimeMixin {}

class LoopFirstOwner extends LevitController
    with LevitLoopMixin, LevitTasksMixin {}

class TasksBeforeLoopOwner extends LevitController
    with LevitTasksMixin, LevitLoopMixin {}

class ProbeService implements LevitLoopService {
  bool stopped = false;
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
    stopped = true;
    await status.close();
  }
}

Future<int> cancellableIsolate(int input, LevitIsolateTaskContext task) async {
  task.reportProgress(.5);
  await task.cancelled;
  return input;
}

void main() {
  test(
    'disposal waits for the body before releasing later-owned resources',
    () async {
      final scope = LevitScope.root();
      final owner = scope.put(Owner.new);
      final state = owner.own(0.lx);
      final started = Completer<void>();
      final release = Completer<void>();
      final result = owner.runTask((task) async {
        started.complete();
        await release
            .future; // Deliberately ignores cancellation until released.
        expect(state.isDisposed, isFalse);
        state.value = 1;
        return 42;
      });
      await started.future;
      var closed = false;
      final cleanup = scope.dispose();
      cleanup.then((_) => closed = true);
      await Future<void>.value();
      expect(owner.isClosing, isTrue);
      expect(closed, isFalse);
      expect(state.isDisposed, isFalse);
      expect(() => owner.runTask((_) => 1), throwsStateError);
      release.complete();
      await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
      await cleanup;
      expect(state.isDisposed, isTrue);
      expect(owner.isDisposed, isTrue);
    },
  );

  for (final create in <LevitController Function()>[
    TimeFirstOwner.new,
    TasksFirstOwner.new,
    LoopFirstOwner.new,
    TasksBeforeLoopOwner.new,
  ]) {
    test(
      'task draining composes with other resource mixins: $create',
      () async {
        final controller = create();
        final service = controller is LevitLoopMixin
            ? controller.loopEngine.registerService('probe', ProbeService())
            : null;
        final timeOwner = controller is LevitTimeMixin ? controller : null;
        final countdown = timeOwner?.startCountdown(
          duration: const Duration(hours: 1),
        );
        final engine = controller is LevitReactiveTasksMixin
            ? controller.taskEngine
            : (controller as LevitTasksMixin).taskEngine;
        final release = Completer<void>();
        final started = Completer<void>();
        final result = engine.schedule((_) async {
          started.complete();
          await release.future;
          if (countdown != null)
            expect(countdown.remaining.isDisposed, isFalse);
          if (service != null) expect(service.stopped, isFalse);
        });
        await started.future;
        final closing = controller.onClose();
        release.complete();
        await closing;
        await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
        if (countdown != null) expect(countdown.remaining.isDisposed, isTrue);
        if (service != null) expect(service.stopped, isTrue);
      },
    );
  }

  test(
    'plain mixin drains and repeated engine disposal shares completion',
    () async {
      final scope = LevitScope.root();
      final owner = scope.put(PlainOwner.new);
      final engine = owner.taskEngine;
      final started = Completer<void>();
      final result = engine.schedule((task) async {
        started.complete();
        await task.cancelled;
        return 1;
      });
      await started.future;
      final first = engine.dispose();
      expect(identical(first, engine.dispose()), isTrue);
      expect(() => engine.schedule((_) => 2), throwsStateError);
      await first;
      await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
      await scope.dispose();
    },
  );

  test('queued work is cancelled without executing', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    final started = Completer<void>();
    final running = engine.schedule((task) async {
      started.complete();
      await task.cancelled;
    });
    await started.future;
    var queuedRan = false;
    final queued = engine.schedule((_) => queuedRan = true);
    await engine.dispose();
    await expectLater(running, throwsA(isA<LevitTaskCancelledException>()));
    await expectLater(queued, throwsA(isA<LevitTaskCancelledException>()));
    expect(queuedRan, isFalse);
  });

  test('retry waiting is interrupted without waiting for its timer', () async {
    final retry = Completer<void>();
    final engine = LevitTaskEngine(
      maxConcurrent: 1,
      onTaskEvent: (event) {
        if (event.type == LevitTaskEventType.retryScheduled) retry.complete();
      },
    );
    var attempts = 0;
    final result = engine.schedule(
      (_) {
        attempts++;
        throw StateError('retry');
      },
      retryPolicy: LevitRetryPolicy(
        shouldRetry: (error, stack) => true,
        maxRetries: 1,
        initialDelay: const Duration(hours: 1),
        maxDelay: const Duration(hours: 1),
        jitter: 0,
      ),
    );
    await retry.future;
    await engine.dispose();
    await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
    expect(attempts, 1);
  });

  test('isolate cancellation drains its runner and port cleanup', () async {
    final progress = Completer<void>();
    final engine = LevitTaskEngine(
      maxConcurrent: 1,
      onTaskEvent: (event) {
        if (event.type == LevitTaskEventType.progress) progress.complete();
      },
    );
    final result = engine.scheduleIsolate(cancellableIsolate, 42);
    await progress.future;
    await engine.dispose();
    await expectLater(result, throwsA(isA<LevitTaskCancelledException>()));
  });

  test('task failure remains on its result, not the disposal future', () async {
    final engine = LevitTaskEngine(maxConcurrent: 1);
    await expectLater(
      engine.schedule((_) => throw StateError('task')),
      throwsStateError,
    );
    await engine.dispose();
  });
}
