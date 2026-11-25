import 'dart:async';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class _DisposableItem implements LevitScopeDisposable {
  final bool failClose;
  bool closed = false;

  _DisposableItem({this.failClose = false});

  @override
  void onInit() {}

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}

  @override
  FutureOr<void> onClose() {
    closed = true;
    if (failClose) throw StateError('close failure');
  }
}

void main() {
  test(
    'lazyPut and lazyPutAsync reject overwriting an in-flight lazyPutAsync singleton',
    () async {
      final scope = LevitScope.root('in_flight');
      final gate = Completer<void>();
      scope.lazyPutAsync<_DisposableItem>(() async {
        await gate.future;
        return _DisposableItem();
      });

      final pending = scope.findAsync<_DisposableItem>();
      expect(
        () => scope.lazyPut<_DisposableItem>(() => _DisposableItem()),
        throwsStateError,
      );
      expect(
        () =>
            scope.lazyPutAsync<_DisposableItem>(() async => _DisposableItem()),
        throwsStateError,
      );

      gate.complete();
      final created = await pending;
      await scope.dispose();
      expect(created.closed, isTrue);
    },
  );

  test(
    'failed releaseFactoryInstance does not fail subsequent healthy releases',
    () async {
      final scope = LevitScope.root('factory_release');
      var count = 0;
      scope.lazyPut<_DisposableItem>(
        () => _DisposableItem(failClose: ++count == 1),
        isFactory: true,
      );

      final failing = scope.find<_DisposableItem>();
      final healthy = scope.find<_DisposableItem>();

      await expectLater(
        scope.releaseFactoryInstance<_DisposableItem>(failing),
        throwsA(isA<LevitDisposalException>()),
      );

      expect(
        await scope.releaseFactoryInstance<_DisposableItem>(healthy),
        isTrue,
      );
      expect(healthy.closed, isTrue);

      await expectLater(
        scope.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
    },
  );

  test(
    'synchronous builders reject deleting their own registration or disposing their scope',
    () async {
      final scope = LevitScope.root('sync_guard');
      scope.lazyPut<_DisposableItem>(() {
        expect(() => scope.delete<_DisposableItem>(), throwsStateError);
        expect(() => scope.dispose(), throwsStateError);
        return _DisposableItem();
      });

      final item = scope.find<_DisposableItem>();
      expect(scope.isRegistered<_DisposableItem>(), isTrue);
      expect(scope.find<_DisposableItem>(), same(item));

      await scope.dispose();
      expect(item.closed, isTrue);
    },
  );
}
