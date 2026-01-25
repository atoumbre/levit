import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('Ls (Global Accessor) Coverage', () {
    tearDown(() {
      Ls.reset(force: true);
    });

    test('Ls.createScope returns a new scope', () {
      final scope = Ls.createScope('test_scope');
      expect(scope.name, 'test_scope');
    });

    test('Ls.registeredCount and registeredKeys', () {
      expect(Ls.registeredCount, 0);
      expect(Ls.registeredKeys, isEmpty);

      Ls.put(() => 'A');
      expect(Ls.registeredCount, 1);
      expect(Ls.registeredKeys, contains('String'));
    });

    test('Ls methods proxy to active scope', () {
      Ls.put(() => 'Dependency', tag: 'tag');
      expect(Ls.isRegistered<String>(tag: 'tag'), isTrue);
      expect(Ls.isInstantiated<String>(tag: 'tag'), isTrue); // put is immediate

      expect(Ls.find<String>(tag: 'tag'), 'Dependency');
      expect(Ls.findOrNull<String>(tag: 'tag'), 'Dependency');
      expect(Ls.findOrNull<String>(tag: 'missing'), isNull);

      Ls.delete<String>(tag: 'tag');
      expect(Ls.isRegistered<String>(tag: 'tag'), isFalse);
    });

    test('Ls.lazyPut proxies', () {
      Ls.lazyPut(() => 10);
      expect(Ls.isRegistered<int>(), isTrue);
      expect(Ls.isInstantiated<int>(), isFalse);
      expect(Ls.find<int>(), 10);
    });

    test('Ls.lazyPutAsync proxies', () async {
      Ls.lazyPutAsync(() async => 20);
      expect(Ls.isRegistered<int>(), isTrue);

      final val = await Ls.findAsync<int>();
      expect(val, 20);
    });

    test('Ls.findOrNullAsync proxies', () async {
      final val = await Ls.findOrNullAsync<double>();
      expect(val, isNull);
    });

    test('Ls.run executes in scope zone', () {
      final scope = Ls.createScope('run_test');
      scope.run(() {
        Ls.put(() => 'ZoneDependency');
        expect(Ls.isRegistered<String>(), isTrue);
        expect(scope.isRegisteredLocally<String>(), isTrue);
      });
      // Root should not have it
      expect(Ls.isRegistered<String>(), isFalse);
    });

    test('scope.dispose and middleware callback', () {
      int disposeCount = 0;
      final mw = TestScopeMiddleware(onDispose: () => disposeCount++);
      Ls.addMiddleware(mw);

      final scope = Ls.createScope('dispose_test');
      scope.dispose();

      expect(disposeCount, 1);
      Ls.removeMiddleware(mw);
    });

    test('Ls.middleware mgmt', () {
      final mw = TestScopeMiddleware();
      Ls.addMiddleware(mw);
      Ls.removeMiddleware(mw);
      // No crash = success
    });
  });
}

class TestScopeMiddleware extends LevitScopeMiddleware {
  final void Function()? onDispose;
  TestScopeMiddleware({this.onDispose});

  @override
  void onScopeDispose(int scopeId, String scopeName) {
    onDispose?.call();
    super.onScopeDispose(scopeId, scopeName);
  }
}
