import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

class TestScopeMiddleware extends LevitScopeMiddleware {
  final void Function()? onDispose;
  TestScopeMiddleware({this.onDispose});
  @override void onScopeDispose(int scopeId, String scopeName) { onDispose?.call(); super.onScopeDispose(scopeId, scopeName); }
}

void main() {
  test('scope.dispose and middleware callback', () {
    int disposeCount = 0;
    final mw = TestScopeMiddleware(onDispose: () => disposeCount++);
    Ls.addMiddleware(mw);

    final scope = Ls.createScope('dispose_test');
    scope.dispose();

    expect(disposeCount, 1);
    Ls.removeMiddleware(mw);
  });
}
