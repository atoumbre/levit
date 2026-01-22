import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware Chain Coverage', () {
    test('triggers LevitScopeMiddlewareChain internal logic', () {
      final middleware = MockDIMiddleware();

      // Use the static method on LevitScope to add middleware
      LevitScope.addMiddleware(middleware);

      final scope = LevitScope.root();
      // Use lazyPut to ensure find() triggers onResolve (factory/lazy init)
      scope.lazyPut(() => 'test');
      scope.find<String>();

      expect(middleware.registerCalled, isTrue);
      expect(middleware.resolveCalled, isTrue);

      LevitScope.removeMiddleware(middleware);
    });
  });
}

class MockDIMiddleware extends LevitScopeMiddleware {
  bool registerCalled = false;
  bool resolveCalled = false;
  bool deleteCalled = false;

  @override
  void onRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    registerCalled = true;
  }

  @override
  void onResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    resolveCalled = true;
  }

  @override
  void onDelete(int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    deleteCalled = true;
  }
}
