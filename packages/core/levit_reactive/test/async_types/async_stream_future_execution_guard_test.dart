import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _BatchOnlyMiddleware extends LevitReactiveMiddleware {
  final recordedBatches = <List<LevitReactiveChange>>[];

  @override
  LxOnBatch? get onBatch => (next, change) {
    return () {
      final result = next();
      recordedBatches.add(List<LevitReactiveChange>.of(change.changes));
      return result;
    };
  };
}

void main() {
  test('LxFuture preserves LxSuccess when a success listener throws', () async {
    final completer = Completer<int>();
    final lxFuture = LxFuture<int>(completer.future);
    lxFuture.addListener(() {
      if (lxFuture.status is LxSuccess<int>) {
        throw StateError('listener failure');
      }
    });

    completer.complete(42);
    await Future<void>.delayed(Duration.zero);

    expect(lxFuture.status, isA<LxSuccess<int>>());
    expect(lxFuture.status.valueOrNull, 42);
    await expectLater(lxFuture.close(), throwsA(isA<LxCleanupException>()));
  });

  test(
    'LxStream forwards upstream errors through valueStream and derived operators',
    () async {
      final controller = StreamController<int>.broadcast();
      final lxStream = LxStream<int>(controller.stream);
      final folded = lxStream.fold<int>(0, (acc, item) => acc + item);

      await Future<void>.delayed(Duration.zero);
      controller.addError(StateError('stream failure'));
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(folded.status, isA<LxError<int>>());
      expect((folded.status as LxError<int>).error, isA<StateError>());
      await folded.close();
      await lxStream.close();
    },
  );

  test(
    'LxExecutionContext tracks nested producers and clears after completion',
    () async {
      final a = 0.lx;
      final b = 0.lx;
      var sawOuterDuringInner = false;
      late void Function() escapedCallback;
      late LxWorker<int> workerA;
      late LxWorker<int> workerB;

      workerB = LxWorker<int>(b, (_) {
        sawOuterDuringInner = LxExecutionContext.isExecuting(workerA);
      });
      workerA = LxWorker<int>(a, (_) {
        escapedCallback = Zone.current.bindCallback(() {});
        b.value++;
      });

      a.value++;
      expect(sawOuterDuringInner, isTrue);

      var executingAfterCompletion = true;
      escapedCallback = Zone.current.bindCallback(() {
        executingAfterCompletion = LxExecutionContext.isExecuting(workerA);
      });
      escapedCallback();
      expect(executingAfterCompletion, isFalse);

      await workerA.close();
      await workerB.close();
    },
  );

  test(
    'LxWorker forwards unhandled async errors to the active zone when monitoring is off',
    () async {
      Lx.enableWatchMonitoring = false;
      final trigger = 0.lx;
      final caught = Completer<Object>();
      late LxWorker<int> worker;

      runZonedGuarded(
        () {
          worker = LxWorker<int>(trigger, (_) async {
            await Future<void>.delayed(Duration.zero);
            throw StateError('worker async error');
          });
          trigger.value++;
        },
        (error, _) {
          if (!caught.isCompleted) caught.complete(error);
        },
      );

      expect(await caught.future, isA<StateError>());
      await worker.close();
    },
  );

  test('batch-only middleware receives change entries', () {
    final middleware = _BatchOnlyMiddleware();
    Lx.addMiddleware(middleware);
    addTearDown(() => Lx.removeMiddleware(middleware));

    final counter = 0.lx;
    Lx.batch(() {
      counter.value = 1;
      counter.value = 2;
    });

    expect(middleware.recordedBatches, hasLength(1));
    expect(middleware.recordedBatches.single, hasLength(2));
    counter.close();
  });

  test('LxSet.assign preserves items on self-assignment and derived views', () {
    final items = <int>{1, 2, 3}.lx;
    items.assign(items);
    expect(items, {1, 2, 3});

    items.assign(items.where((value) => value > 1));
    expect(items, {2, 3});
    items.close();
  });
}
