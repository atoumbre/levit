import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _Owner extends LevitController {}

class _InitializingOwner extends LevitController {
  _InitializingOwner(this.initialize, this.work);
  final Future<void> initialize;
  final Future<int> work;
  LxFuture<int>? state;
  @override
  Future<void> onInit() async {
    super.onInit();
    await initialize;
    state = LxFuture(work);
  }
}

void main() {
  test(
    'late initialization capture is drained before owner cleanup completes',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      final initialize = Completer<void>();
      final work = Completer<int>();
      final owner = scope.put(
        () => _InitializingOwner(initialize.future, work.future),
      );
      var done = false;
      final cleanup = scope.dispose().then((_) => done = true);
      initialize.complete();
      await Future<void>.delayed(Duration.zero);
      expect(owner.state, isNotNull);
      expect(done, isFalse);
      work.complete(1);
      await cleanup;
      expect(owner.state!.isDisposed, isTrue);
      Levit.disableAutoLinking();
    },
  );

  test(
    'direct controller close drains pending async initialization capture',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      final initialize = Completer<void>();
      final work = Completer<int>();
      final owner = scope.put(
        () => _InitializingOwner(initialize.future, work.future),
      );
      var closed = false;
      final closing = Future<void>.sync(
        owner.onClose,
      ).then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      initialize.complete();
      await Future<void>.delayed(Duration.zero);
      expect(owner.state, isNotNull);
      expect(closed, isFalse);
      work.complete(7);
      await closing;
      expect(owner.state!.isDisposed, isTrue);
      await scope.dispose();
      Levit.disableAutoLinking();
    },
  );

  test(
    'owner drains work before releasing state regardless of ownership order',
    () async {
      final owner = _Owner();
      final trigger = 0.lx;
      final finish = Completer<void>();
      late LxVar<int> state;
      final observations = <bool>[];
      owner.own(
        LxWorker(trigger, (_) async {
          try {
            await finish.future;
          } finally {
            observations.add(state.isDisposed);
          }
        }),
      );
      state = owner.own(0.lx);
      trigger.value++;
      var closed = false;
      final closing = Future<void>.sync(
        owner.onClose,
      ).then((_) => closed = true);
      await Future<void>.value();
      expect(state.isDisposed, isFalse);
      expect(closed, isFalse);
      expect(() => owner.own(1.lx), throwsStateError);
      finish.complete();
      await closing;
      expect(observations, [false]);
      expect(state.isDisposed, isTrue);
      await trigger.close();
    },
  );

  test(
    'explicit disposer replaces duck-typed cleanup and is awaited once',
    () async {
      final owner = _Owner();
      final resource = Object();
      expect(() => owner.own(resource), throwsArgumentError);
      final gate = Completer<void>();
      var calls = 0;
      owner.own(
        resource,
        dispose: (_) async {
          calls++;
          await gate.future;
        },
      );
      owner.own(resource, dispose: (_) => fail('duplicate disposer'));
      final closing = Future<void>.sync(owner.onClose);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(owner.isDisposed, isFalse);
      gate.complete();
      await closing;
      await owner.onClose();
      expect(calls, 1);
    },
  );

  test('owned worker cannot await disposal of its owner', () async {
    final owner = _Owner();
    final source = 0.lx;
    final checked = Completer<void>();
    owner.own(
      LxWorker(source, (_) async {
        expect(owner.onClose, throwsStateError);
        checked.complete();
      }),
    );
    source.value++;
    await checked.future;
    expect(owner.isClosed, isFalse);
    await owner.onClose();
    await source.close();
  });
}
