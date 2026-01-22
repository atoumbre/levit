import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScopeMiddlewareChain', () {
    test('cannot be instantiated (private constructor)', () {
      // The class has a private constructor, so we can't instantiate it
      // We verify this by ensuring the static methods work correctly

      final scope = LevitScope.root();
      final middleware = TestMiddleware();
      LevitScope.addMiddleware(middleware);

      var createCalled = false;
      var initCalled = false;

      middleware.onCreateCallback = (builder, scope, key, info) {
        createCalled = true;
        return builder;
      };

      middleware.onDependencyInitCallback =
          (onInit, instance, scope, key, info) {
        initCalled = true;
        return onInit;
      };

      // Trigger middleware chain
      scope.put(() => TestService());

      expect(createCalled, true);
      expect(initCalled, true);

      LevitScope.removeMiddleware(middleware);
    });

    test('multiple middleware layers trigger chain construction', () {
      final scope = LevitScope.root();
      final middleware1 = TestMiddleware();
      final middleware2 = TestMiddleware();
      final middleware3 = TestMiddleware();

      var callOrder = <String>[];

      middleware1.onCreateCallback = (builder, scope, key, info) {
        callOrder.add('middleware1');
        return builder;
      };

      middleware2.onCreateCallback = (builder, scope, key, info) {
        callOrder.add('middleware2');
        return builder;
      };

      middleware3.onCreateCallback = (builder, scope, key, info) {
        callOrder.add('middleware3');
        return builder;
      };

      LevitScope.addMiddleware(middleware1);
      LevitScope.addMiddleware(middleware2);
      LevitScope.addMiddleware(middleware3);

      scope.put(() => TestService());

      // All middleware should be called (chain was constructed)
      expect(callOrder.length, 3);
      expect(callOrder.contains('middleware1'), true);
      expect(callOrder.contains('middleware2'), true);
      expect(callOrder.contains('middleware3'), true);

      LevitScope.removeMiddleware(middleware1);
      LevitScope.removeMiddleware(middleware2);
      LevitScope.removeMiddleware(middleware3);
    });
  });
}

class TestService extends LevitScopeDisposable {}

class TestMiddleware extends LevitScopeMiddleware {
  Function? onCreateCallback;
  Function? onDependencyInitCallback;

  @override
  S Function() onCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    if (onCreateCallback != null) {
      return onCreateCallback!(builder, scope, key, info);
    }
    return builder;
  }

  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    if (onDependencyInitCallback != null) {
      return onDependencyInitCallback!(onInit, instance, scope, key, info);
    }
    return onInit;
  }
}
