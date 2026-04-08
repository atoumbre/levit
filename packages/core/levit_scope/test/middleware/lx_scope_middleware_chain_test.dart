import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class MockDIMiddleware extends LevitScopeMiddleware {
  bool registerCalled = false;
  bool resolveCalled = false;
  @override
  void onDependencyRegister(int id, String n, String k, LevitDependency i,
          {required String source, int? parentScopeId}) =>
      registerCalled = true;
  @override
  void onDependencyResolve(int id, String n, String k, LevitDependency i,
          {required String source, int? parentScopeId}) =>
      resolveCalled = true;
}

void main() {
  test('triggers LevitScopeMiddlewareChain internal logic', () {
    final middleware = MockDIMiddleware();
    LevitScope.addMiddleware(middleware);
    final scope = LevitScope.root();
    scope.lazyPut(() => 'test');
    scope.find<String>();
    expect(middleware.registerCalled, isTrue);
    expect(middleware.resolveCalled, isTrue);
    LevitScope.removeMiddleware(middleware);
  });
}
