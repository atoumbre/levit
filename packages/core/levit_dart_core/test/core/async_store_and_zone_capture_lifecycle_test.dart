import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _Resource implements LevitDisposable {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

class _LiveCallbackController extends LevitController {
  late LxVar<int> Function() createOutsideInit;

  @override
  void onInit() {
    super.onInit();
    createOutsideInit = Zone.current.bindCallback(() => 99.lx);
  }
}

void main() {
  test(
    'LevitAsyncStore drains before scope disposal even without auto-linking',
    () async {
      Levit.disableAutoLinking();
      final scope = LevitScope.root('async_store_drain');
      final started = Completer<void>();
      final gate = Completer<void>();
      final resource = _Resource();

      final store = LevitAsyncStore<_Resource>((ref) async {
        started.complete();
        await gate.future;
        return ref.own(resource);
      });

      final lookup = store.findIn(scope);
      await started.future;

      var disposed = false;
      final disposing = scope.dispose().then((_) => disposed = true);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);

      gate.complete();
      await expectLater(lookup, throwsStateError);
      await disposing;
      expect(disposed, isTrue);
    },
  );

  test(
    'escaped onInit callback does not attach reactives to a live owner during unrelated capture',
    () async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);

      final scope = LevitScope.root('zone_isolation');
      final owner = scope.put(_LiveCallbackController.new);

      late LxVar<int> externalReactive;
      final secondScope = LevitScope.root('other_owner');
      final otherGate = Completer<void>();
      secondScope.lazyPutAsync<int>(() async {
        externalReactive = owner.createOutsideInit();
        await otherGate.future;
        return 1;
      });
      final pending = secondScope.findAsync<int>();
      otherGate.complete();
      await pending;

      await scope.dispose();
      // Because owner's onInit had already ended, externalReactive was not adopted.
      expect(externalReactive.isDisposed, isFalse);

      await secondScope.dispose();
      await externalReactive.close();
    },
  );
}
