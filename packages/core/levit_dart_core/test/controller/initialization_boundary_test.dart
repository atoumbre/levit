import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class SimpleOwner extends LevitController {}

class InitializingOwner extends LevitController {
  bool rejected = false;
  final ready = Completer<void>();
  @override
  Future<void> onInit() async {
    super.onInit();
    await Future<void>.value();
    try {
      final closing = onClose();
      if (closing is Future) closing.ignore();
    } on StateError {
      rejected = true;
    }
    ready.complete();
  }
}

class SyncFailureOwner extends LevitController {
  @override
  void onInit() {
    super.onInit();
    throw StateError('initialization');
  }
}

class InitializingService extends LevitScopeDisposable {
  InitializingService(this.scope);
  final LevitScope scope;
  final ready = Completer<void>();
  @override
  Future<void> onInit() async {
    await Future<void>.value();
    expect(() => scope.dispose(), throwsStateError);
    ready.complete();
  }
}

void main() {
  tearDown(Levit.disableAutoLinking);

  test(
    'early-releasing owners retain their scope execution boundary',
    () async {
      final scope = LevitScope.root();
      scope.lazyPut<LevitController>(SimpleOwner.new, isFactory: true);
      final owner = scope.find<LevitController>();
      final source = owner.own(0.lx);
      final entered = Completer<void>();
      final continueWork = Completer<void>();
      var rejected = false;
      owner.own(
        LxWorker(source, (_) async {
          entered.complete();
          await continueWork.future;
          try {
            scope.assertCanDispose();
          } on StateError {
            rejected = true;
          }
        }),
      );
      source.value++;
      await entered.future;
      final releasing = scope.releaseFactoryInstance(owner);
      expect(await scope.releaseFactoryInstance(owner), isFalse);
      continueWork.complete();
      expect(await releasing, isTrue);
      await scope.dispose();
      expect(rejected, isTrue);
    },
  );

  for (final factory in [false, true]) {
    test(
      'owned worker cannot remove its registration, factory=$factory',
      () async {
        final scope = LevitScope.root();
        scope.lazyPut<LevitController>(SimpleOwner.new, isFactory: factory);
        final owner = scope.find<LevitController>();
        final source = owner.own(0.lx);
        final checked = Completer<void>();
        owner.own(
          LxWorker(source, (_) async {
            await expectLater(
              scope.delete<LevitController>(),
              throwsStateError,
            );
            await expectLater(scope.reset(), throwsStateError);
            if (factory) {
              await expectLater(
                scope.releaseFactoryInstance(owner),
                throwsStateError,
              );
            }
            expect(scope.isRegistered<LevitController>(), isTrue);
            checked.complete();
          }),
        );
        source.value++;
        await checked.future;
        if (factory) expect(await scope.releaseFactoryInstance(owner), isTrue);
        await scope.dispose();
      },
    );
  }

  test(
    'tracked initialization of a non-owner service cannot close its scope',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      final service = scope.put(() => InitializingService(scope));
      await service.ready.future;
      await scope.dispose();
    },
  );

  test(
    'async store initialization cannot close its containing scope',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      final store = LevitAsyncStore<int>((ref) async {
        await Future<void>.value();
        expect(() => ref.scope.dispose(), throwsStateError);
        return 42;
      });
      expect(await store.findIn(scope), 42);
      await scope.dispose();
    },
  );

  test(
    'failed synchronous owner initialization does not retain an active guard',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      expect(() => scope.put(SyncFailureOwner.new), throwsStateError);
      await scope.dispose();
    },
  );
  test(
    'async initialization cannot await disposal of its own resources',
    () async {
      Levit.enableAutoLinking();
      final scope = LevitScope.root();
      final owner = scope.put(InitializingOwner.new);
      await owner.ready.future;
      await scope.dispose();
      expect(owner.rejected, isTrue);
    },
  );
}
