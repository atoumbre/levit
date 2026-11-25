import 'dart:async';
import 'dart:isolate';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_dart/tasks.dart';
import 'package:test/test.dart';

class _FailingSuperController extends LevitController {
  _FailingSuperController(this.errorToThrow);

  final Object errorToThrow;

  @override
  FutureOr<void> onBeforeClose() async {
    await super.onBeforeClose();
    throw errorToThrow;
  }
}

class _TasksWithFailingSuper extends _FailingSuperController
    with LevitTasksMixin {
  _TasksWithFailingSuper(super.errorToThrow);
}

class _ReactiveTasksWithCleanup extends LevitController
    with LevitReactiveTasksMixin {
  @override
  int get maxConcurrentTasks => 1;

  @override
  Duration? get autoCleanupDelay => const Duration(milliseconds: 5);

  @override
  void Function(LevitTaskEvent event)? get onTaskEvent => (event) {
    if (event.taskId == 'cancel-on-queue' &&
        event.type == LevitTaskEventType.queued) {
      cancelTask('cancel-on-queue');
    }
  };
}

class _NonSendableError implements Exception {
  _NonSendableError(this.port);
  final ReceivePort port;
  @override
  String toString() => 'NonSendableError';
}

Future<int> _noopIsolateTask(int input, LevitIsolateTaskContext context) async {
  return input;
}

Future<void> _exitIsolateLoop() async {
  Isolate.exit();
}

Future<void> _uncaughtIsolateLoop() async {
  Timer.run(() => throw StateError('uncaught isolate failure'));
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

Future<void> _nonSendableErrorLoop() async {
  final port = ReceivePort();
  try {
    throw _NonSendableError(port);
  } finally {
    port.close();
  }
}

void main() {
  group('Task mixin teardown and completed isolate submissions', () {
    test(
      'aggregates LevitDisposalException and plain errors during close',
      () async {
        final disposalErr = LevitDisposalException([
          LevitDisposalFailure(
            resource: Object(),
            error: StateError('super disposal'),
            stackTrace: StackTrace.current,
          ),
        ]);
        final first = _TasksWithFailingSuper(disposalErr);
        first.onInit();
        await expectLater(
          first.onClose(),
          throwsA(isA<LevitDisposalException>()),
        );

        final second = _TasksWithFailingSuper(StateError('plain failure'));
        second.onInit();
        await expectLater(
          second.onClose(),
          throwsA(isA<LevitDisposalException>()),
        );
      },
    );

    test(
      'schedules cleanup for immediately expired isolate task and allows clearTask after close',
      () async {
        final controller = _ReactiveTasksWithCleanup();
        controller.onInit();

        final gate = Completer<void>();
        final running = controller.runTask<void>(
          (_) => gate.future,
          id: 'blocker',
        );
        await expectLater(
          controller.runIsolateTask<int, int>(
            _noopIsolateTask,
            1,
            id: 'cancel-on-queue',
          ),
          throwsA(isA<LevitTaskCancelledException>()),
        );
        expect(
          controller.tasks['cancel-on-queue']?.phase,
          LevitTaskPhase.completed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(controller.tasks.containsKey('cancel-on-queue'), isFalse);

        gate.complete();
        await running;

        await controller.onClose();
        controller.clearTask('missing-after-close');
      },
    );

    test('group body cannot await disposal of its own task engine', () async {
      final engine = LevitTaskEngine(maxConcurrent: 2);
      await expectLater(
        engine.rootGroup.runGroup((group) async {
          await engine.dispose();
        }, name: 'self-dispose-group'),
        throwsA(isA<LevitTaskGroupException>()),
      );
      await engine.dispose();
    });
  });

  group('Isolate loop error and exit handling', () {
    test(
      'completes cleanly when isolate exits abruptly via Isolate.exit',
      () async {
        final engine = LevitLoopEngine();
        engine.startIsolateLoop('exit-loop', _exitIsolateLoop);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await engine.dispose();
      },
    );

    test('captures uncaught isolate errors via onError port', () async {
      final engine = LevitLoopEngine();
      engine.startIsolateLoop('uncaught-loop', _uncaughtIsolateLoop);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await engine.dispose();
    });

    test(
      'falls back to RemoteError when isolate throws a non-sendable error',
      () async {
        final engine = LevitLoopEngine();
        engine.startIsolateLoop(
          'nonsendable-loop',
          _nonSendableErrorLoop,
          delay: const Duration(milliseconds: 10),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await engine.dispose();
      },
    );
  });
}
