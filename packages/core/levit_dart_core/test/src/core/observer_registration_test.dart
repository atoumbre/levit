import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class TestObserver extends LevitScopeMiddleware {
  int registerCount = 0;

  @override
  void onDependencyRegister(
      int scopeId, String scopeName, String key, dynamic info,
      {required String source, int? parentScopeId}) {
    registerCount++;
  }

  @override
  void onDependencyDelete(
      int scopeId, String scopeName, String key, dynamic info,
      {required String source, int? parentScopeId}) {}
}

class Service {}

void main() {
  group('Levit Observer Registration', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('addDependencyMiddleware registers middleware', () {
      final observer = TestObserver();
      Levit.addDependencyMiddleware(observer);

      Levit.put(() => Service());
      expect(observer.registerCount, 1);
    });

    test('removeDependencyMiddleware un-registers middleware', () {
      final observer = TestObserver();
      Levit.addDependencyMiddleware(observer);
      Levit.removeDependencyMiddleware(observer);

      Levit.put(() => Service());
      expect(observer.registerCount, 0);
    });
  });
}
