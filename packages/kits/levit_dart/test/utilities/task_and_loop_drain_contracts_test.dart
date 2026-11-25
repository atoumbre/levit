import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart/tasks.dart';

class _ReactiveTaskController extends LevitController
    with LevitReactiveTasksMixin {}

class _CancelOnQueuedMiddleware extends LevitTaskMiddleware {
  final LevitTaskEngine engine;
  final String targetId;

  _CancelOnQueuedMiddleware(this.engine, this.targetId);

  @override
  void onTaskEvent(LevitTaskEvent event) {
    if (event.taskId == targetId && event.type == LevitTaskEventType.queued) {
      engine.cancel(targetId);
    }
  }
}

class _CorruptCacheProvider implements LevitTaskCacheProvider {
  final Map<String, Map<String, dynamic>> entries = {
    'corrupt': {'expiresAt': 'not-an-int', 'data': {}},
  };

  @override
  Future<void> delete(String key) async {
    entries.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    entries[key] = data;
  }
}

FutureOr<void> _noopIsolateLoop() {}

void main() {
  test(
    'LevitTaskEngine.drain and LevitTaskGroup.drain complete without prior requestCancel',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      final group = LevitTaskGroup(engine: engine);

      await group.drain().timeout(const Duration(seconds: 2));
      await engine.drain().timeout(const Duration(seconds: 2));
      await engine.dispose();
    },
  );

  test('parent LevitTaskGroup body can dispose a child group', () async {
    final engine = LevitTaskEngine(maxConcurrent: 2);
    await engine.rootGroup.runGroup((parent) async {
      final child = LevitTaskGroup(engine: engine, parent: parent);
      await child.dispose();
      expect(child.isComplete, isTrue);
    });
    await engine.dispose();
  });

  test(
    'LevitTaskGroup.runGroup rejects inside a leaf task without leaking a child group',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1);
      await engine.schedule((context) async {
        await expectLater(
          context.group.runGroup(
            (_) {},
            deadline: DateTime.now().add(const Duration(hours: 1)),
          ),
          throwsStateError,
        );
      });

      expect(engine.taskTree.value.children, isEmpty);
      await engine.dispose();
    },
  );

  test(
    'LevitTaskConflictPolicy.restart preserves running task when queue is at maxPending',
    () async {
      final engine = LevitTaskEngine(maxConcurrent: 1, maxPending: 1);
      final started = Completer<void>();
      final release = Completer<void>();

      final first = engine.submit<int>((ctx) async {
        started.complete();
        await release.future;
        ctx.throwIfCancelled();
        return 1;
      }, id: 'job');
      await started.future;

      final queued = engine.submit<int>((_) => 2, id: 'other');

      expect(
        () => engine.submit<int>(
          (_) => 3,
          id: 'job',
          conflictPolicy: LevitTaskConflictPolicy.restart,
        ),
        throwsA(isA<LevitTaskQueueFullException>()),
      );

      release.complete();
      expect(await first.result, 1);
      expect(await queued.result, 2);
      await engine.dispose();
    },
  );

  test(
    'corrupt expiresAt in task cache is deleted and falls back to execution',
    () async {
      final cache = _CorruptCacheProvider();
      final engine = LevitTaskEngine(maxConcurrent: 1, cacheProvider: cache);

      final result = await engine.schedule<int>(
        (_) => 42,
        id: 'corrupt',
        cachePolicy: LevitTaskCachePolicy<int>(
          key: 'corrupt',
          ttl: const Duration(minutes: 5),
          toJson: (v) => {'v': v},
          fromJson: (json) => json['v'] as int,
        ),
      );

      expect(result, 42);
      expect(cache.entries['corrupt']?['expiresAt'], isA<int>());
      await engine.dispose();
    },
  );

  test(
    'LevitLoopEngine ignores pause and resume after requestCancel and stop',
    () async {
      final engine = LevitLoopEngine();
      engine.startLoop('tick', () async {}, delay: const Duration(seconds: 1));
      engine.pauseService('tick');

      final stopping = engine.stopService('tick');
      expect(() => engine.resumeService('tick'), returnsNormally);
      expect(() => engine.pauseService('tick'), returnsNormally);
      await stopping;
      await engine.dispose();
    },
  );

  test('isolate loop pause before handshake does not overwrite stop', () async {
    final engine = LevitLoopEngine();
    engine.startIsolateLoop(
      'iso',
      _noopIsolateLoop,
      delay: const Duration(milliseconds: 50),
    );
    final stopping = engine.stopService('iso');
    engine.pauseService('iso');
    engine.resumeService('iso');

    await stopping.timeout(const Duration(seconds: 5));
    await engine.dispose();
  });

  test(
    'LevitAsyncMap.isFresh is true during LxSuccess notification and false while closing',
    () async {
      final gate = Completer<int>();
      late LevitAsyncMap<String, int> map;
      map = LevitAsyncMap<String, int>((_, _) => gate.future);

      bool? freshInsideListener;
      final entry = map.entry('k');
      entry.addListener(() {
        if (entry.value is LxSuccess<int>) {
          freshInsideListener = map.isFresh('k');
        }
      });

      gate.complete(7);
      await Future<void>.delayed(Duration.zero);
      expect(freshInsideListener, isTrue);

      map.requestCancel();
      expect(map.isFresh('k'), isFalse);
      await map.dispose();
    },
  );

  test(
    'LevitReactiveTasksMixin does not leave isBusy true on synchronous cancel during submit',
    () async {
      final scope = LevitScope.root('sync_cancel');
      final controller = scope.put(_ReactiveTaskController.new);
      final middleware = _CancelOnQueuedMiddleware(
        controller.taskEngine,
        'cancel_me',
      );
      LevitTaskMiddleware.add(middleware);
      addTearDown(() => LevitTaskMiddleware.remove(middleware));

      await expectLater(
        controller.runTask((_) => 1, id: 'cancel_me'),
        throwsA(isA<LevitTaskCancelledException>()),
      );

      expect(controller.isBusy.value, isFalse);
      expect(controller.tasks['cancel_me']?.phase, LevitTaskPhase.completed);
      await scope.dispose();
    },
  );
}
