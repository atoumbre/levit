import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('Levit Init Hooks', () {
    test('LevitScopeMiddleware.onDependencyInit works', () {
      var hookCalled = 0;

      void Function() myHook<S>(
        void Function() onInit,
        S instance,
        LevitScope scope,
        String key,
        LevitDependency info,
      ) {
        return () {
          hookCalled++;
          onInit();
        };
      }

      final levit = LevitScope.root();

      final observer = _TestInitObserver(myHook);

      LevitScope.addMiddleware(observer);

      levit.put(() => MyService());
      expect(hookCalled, equals(1));

      LevitScope.removeMiddleware(observer);
      levit.delete<MyService>();

      levit.put(() => MyService());
      expect(hookCalled,
          equals(1)); // Still 1 because we test removal logic is correct?
      // Wait, passing 1 means it was NOT called the second time (1+0=1)
      // If hook was called it would be 2.
    });
  });
}

class _TestInitObserver extends LevitScopeMiddleware {
  final void Function() Function<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) hook;

  const _TestInitObserver(this.hook);

  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return hook<S>(onInit, instance, scope, key, info);
  }
}

class MyService implements LevitScopeDisposable {
  @override
  void onInit() {}

  @override
  void onClose() {}

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
}
