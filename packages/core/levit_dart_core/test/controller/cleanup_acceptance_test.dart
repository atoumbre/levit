import 'dart:async';
import 'package:levit_dart_core/levit_testing.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/spi.dart';

class Owner extends LevitController {
  Owner({this.before});
  final FutureOr<void> Function()? before;
  @override
  Future<void> onBeforeClose() async {
    await super.onBeforeClose();
    await before?.call();
  }
}

class BrokenDrainOwner extends Owner {
  @override
  Future<void> drain() async {
    await super.drain();
    throw StateError('owner drain');
  }
}

class Work implements LevitDisposable, LevitDrainable {
  Work(this.events, this.problem);
  final List<String> events;
  final Object problem;
  @override
  void requestCancel() {
    events.add('cancel');
    throw problem;
  }

  @override
  Future<void> drain() async {
    events.add('drain');
    throw problem;
  }

  @override
  Future<void> dispose() async {
    events.add('close');
    throw problem;
  }
}

class MemorySink implements Sink<int> {
  bool closed = false;
  @override
  void add(int value) {}
  @override
  void close() {
    closed = true;
  }
}

class FailedReactive extends LxVar<int> {
  FailedReactive(this.problem) : super(0);
  final Object problem;
  @override
  Future<void> close() async {
    await super.close();
    throw problem;
  }
}

class AsyncOwner extends LevitController {
  AsyncOwner(this.ready);
  final Future<void> ready;
  @override
  Future<void> onInit() async {
    super.onInit();
    await ready;
  }
}

class CallbackOwner extends LevitController {
  late void Function() callback;
  @override
  void onInit() {
    super.onInit();
    callback = Zone.current.bindCallback(() {
      0.lx;
    });
  }
}

void main() {
  test(
    'expired initialization capture cannot adopt late callback state',
    () async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);
      final scope = Levit.createScope('expired capture');
      final owner = scope.put(CallbackOwner.new);
      await scope.dispose();
      expect(
        () => LevitAutoLinkSpi.runCaptured(owner.callback),
        throwsStateError,
      );
      expect(owner.isDisposed, isTrue);
    },
  );

  test(
    'owner attempts every phase and flattens duplicate nested failures',
    () async {
      final events = <String>[];
      final error = StateError('resource');
      final hookError = StateError('hook');
      final other = StateError('other close');
      final owner = Owner(
        before: () => throw LevitDisposalException([
          LevitDisposalFailure(
            resource: 'hook',
            error: hookError,
            stackTrace: StackTrace.current,
          ),
        ]),
      );
      final work = owner.own(Work(events, error));
      owner.own(
        Object(),
        dispose: (_) => throw LevitDisposalException([
          LevitDisposalFailure(
            resource: 'other',
            error: other,
            stackTrace: StackTrace.current,
          ),
        ]),
      );
      owner.own(() {
        events.add('dependency closed');
      });
      final closing = owner.onClose();
      await expectLater(
        closing,
        throwsA(
          isA<LevitDisposalException>().having(
            (e) => e.failures.map((f) => f.error),
            'failures',
            unorderedEquals([error, hookError, other]),
          ),
        ),
      );
      await owner.disposed;
      expect(owner.isDisposed, isTrue);
      expect(
        events,
        containsAll(['cancel', 'drain', 'close', 'dependency closed']),
      );
      expect(
        work.events.indexOf('drain'),
        lessThan(work.events.indexOf('dependency closed')),
      );
    },
  );

  test('overridden drain failure still releases remaining resources', () async {
    final owner = BrokenDrainOwner();
    var released = false;
    owner.own(() => released = true);
    await expectLater(
      Future<void>.sync(owner.onClose),
      throwsA(isA<LevitDisposalException>()),
    );
    expect(released, isTrue);
    await owner.disposed;
  });

  test('plain sink ownership uses its supported adapter', () async {
    final owner = Owner();
    final sink = owner.own(MemorySink());
    expect(() => owner.own(Object()), throwsArgumentError);
    await owner.onClose();
    expect(sink.closed, isTrue);
  });

  test(
    'test scope drains tracked work and reports task plus teardown failures',
    () async {
      final boundary = LevitTestScope();
      final gate = Completer<int>();
      final taskError = StateError('task');
      final closeError = StateError('cleanup');
      final owner = boundary.scope.put(() => Owner());
      owner.own(() => throw closeError);
      final task = boundary.track(gate.future);
      final taskObserved = expectLater(task, throwsA(same(taskError)));
      var done = false;
      final closing = boundary.close();
      final checked = expectLater(
        closing,
        throwsA(
          isA<LevitTestException>().having(
            (e) => e.toString(),
            'both errors',
            allOf(contains('task'), contains('cleanup')),
          ),
        ),
      ).then((_) => done = true);
      expect(boundary.close(), same(closing));
      expect(() => boundary.track(Future.value(1)), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gate.completeError(taskError);
      await taskObserved;
      await checked;
    },
  );

  test(
    'test scope awaits successful tracked work and typed async override',
    () async {
      final boundary = LevitTestScope();
      final recipe = LevitStore.async<String>((_) async => 'production');
      boundary.scope.overrideAsyncStore(
        recipe,
        (_) async => 'test',
        tag: 'variant',
      );
      final result = await boundary.track(
        recipe.findIn(boundary.scope, tag: 'variant'),
      );
      await boundary.settle();
      expect(result, 'test');
      await boundary.close();
    },
  );

  test('async owner initialization errors remain in awaited cleanup', () async {
    Levit.enableAutoLinking();
    addTearDown(Levit.disableAutoLinking);
    final scope = Levit.createScope('async owner');
    final ready = Completer<void>();
    final owner = scope.put(() => AsyncOwner(ready.future));
    final problem = StateError('init');
    ready.completeError(problem);
    await expectLater(
      scope.dispose(),
      throwsA(
        isA<LevitDisposalException>().having(
          (e) => e.failures.single.error,
          'initialization',
          same(problem),
        ),
      ),
    );
    await owner.disposed;
  });

  test(
    'failed captured construction drains reactives and surfaces cleanup error',
    () async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);
      final finished = Completer<void>();
      final reported = <Object>[];
      final problem = StateError('capture cleanup');
      runZonedGuarded(
        () {
          final building = LevitAutoLinkSpi.runCaptured<Future<void>>(() async {
            FailedReactive(problem);
            throw StateError('builder');
          });
          unawaited(building.catchError((Object _) {}));
        },
        (error, stack) {
          reported.add(error);
          finished.complete();
        },
      );
      await finished.future;
      expect(reported.single, isA<LevitDisposalException>());
      expect(
        (reported.single as LevitDisposalException).failures.single.error,
        same(problem),
      );
    },
  );

  test('synchronous failed capture closes every allocation', () async {
    Levit.enableAutoLinking();
    addTearDown(Levit.disableAutoLinking);
    late LxVar<int> allocated;
    expect(
      () => LevitAutoLinkSpi.runCaptured(() {
        allocated = 0.lx;
        throw StateError('builder');
      }),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    expect(allocated.isDisposed, isTrue);
  });
}
