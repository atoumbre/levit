import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

/// A mock observer that records events for verification.
class MockObserver extends LevitScopeMiddleware {
  final List<String> events = [];

  @override
  void onRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    events.add('register:$source:$scopeName:$key:$scopeId');
  }

  @override
  void onResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    events.add('resolve:$source:$scopeName:$key:$scopeId');
  }

  @override
  void onDelete(int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {
    events.add('delete:$source:$scopeName:$key:$scopeId');
  }
}

class SimpleService extends LevitScopeDisposable {
  final String name;
  SimpleService(this.name);
}

class AsyncService extends LevitScopeDisposable {}

// This observer specifically tests the default implementation (no-op)
class DefaultObserver extends LevitScopeMiddleware {
  const DefaultObserver();
}

void main() {
  late MockObserver observer;
  late LevitScope levit;
  setUp(() {
    levit = LevitScope.root();
    observer = MockObserver();
    LevitScope.addMiddleware(observer);
  });

  tearDown(() {
    LevitScope.removeMiddleware(observer);
    levit.reset(force: true);
  });

  group('LevitScopeMiddleware', () {
    group('onRegister', () {
      test('is called for put', () {
        levit.put(() => SimpleService('test'));
        expect(observer.events,
            anyElement(startsWith('register:put:root:SimpleService')));
      });

      test('is called for lazyPut', () {
        levit.lazyPut(() => SimpleService('lazy'));
        expect(observer.events,
            anyElement(startsWith('register:lazyPut:root:SimpleService')));
      });

      test('is called for putFactory', () {
        levit.lazyPut(() => SimpleService('factory'), isFactory: true);
        expect(observer.events,
            anyElement(startsWith('register:putFactory:root:SimpleService')));
      });

      test('is called for lazyPutAsync', () {
        levit.lazyPutAsync(() async => AsyncService());
        expect(observer.events,
            anyElement(startsWith('register:lazyPutAsync:root:AsyncService')));
      });

      test('is called for putFactoryAsync', () {
        levit.lazyPutAsync(() async => AsyncService(), isFactory: true);
        expect(
            observer.events,
            anyElement(
                startsWith('register:putFactoryAsync:root:AsyncService')));
      });

      test('is called for put (simulated async)', () async {
        final instance = await Future.value(AsyncService());
        levit.put(() => instance);
        // putAsync calls put internally
        expect(observer.events,
            anyElement(startsWith('register:put:root:AsyncService')));
      });

      test('is called with correct scope name for child scopes', () {
        final childScope = levit.createScope('child');
        childScope.put(() => SimpleService('test'));
        expect(observer.events,
            anyElement(startsWith('register:put:child:SimpleService')));
      });
    });

    group('onResolve', () {
      test('is called for find on lazy instance', () {
        levit.lazyPut(() => SimpleService('lazy'));
        observer.events.clear();

        levit.find<SimpleService>();
        expect(observer.events,
            anyElement(startsWith('resolve:find:root:SimpleService')));
      });

      test('is called for each factory find', () {
        levit.lazyPut(() => SimpleService('factory'), isFactory: true);
        observer.events.clear();

        levit.find<SimpleService>();
        levit.find<SimpleService>();
        expect(
            observer.events.where((e) => e.startsWith('resolve:')).length, 2);
      });

      test('is called for findAsync on lazy async instance', () async {
        levit.lazyPutAsync(() async => AsyncService());
        observer.events.clear();

        await levit.findAsync<AsyncService>();
        expect(observer.events,
            anyElement(startsWith('resolve:findAsync:root:AsyncService')));
      });

      test('is called for findAsync on async factory', () async {
        levit.lazyPutAsync(() async => AsyncService(), isFactory: true);
        observer.events.clear();

        await levit.findAsync<AsyncService>();
        expect(observer.events,
            anyElement(startsWith('resolve:findAsync:root:AsyncService')));
      });
    });

    group('onDelete', () {
      test('is called for delete', () {
        levit.put(() => SimpleService('test'));
        observer.events.clear();

        levit.delete<SimpleService>();
        expect(observer.events,
            anyElement(startsWith('delete:delete:root:SimpleService')));
      });

      test('is called for reset', () {
        levit.put(() => SimpleService('test'));
        observer.events.clear();

        levit.reset();
        expect(observer.events,
            anyElement(startsWith('delete:reset:root:SimpleService')));
      });

      test('is called for each item during reset', () {
        levit.put(() => SimpleService('svc1'), tag: 'a');
        levit.put(() => SimpleService('svc2'), tag: 'b');
        observer.events.clear();

        levit.reset();
        expect(observer.events.where((e) => e.startsWith('delete:')).length, 2);
      });
    });

    group('multiple observers', () {
      test('all observers are notified', () {
        final observer2 = MockObserver();
        LevitScope.addMiddleware(observer2);

        levit.put(() => SimpleService('test'));

        expect(observer.events,
            anyElement(startsWith('register:put:root:SimpleService')));
        expect(observer2.events,
            anyElement(startsWith('register:put:root:SimpleService')));

        LevitScope.removeMiddleware(observer2);
      });
    });
    group('DefaultObserver Coverage', () {
      test('default methods perform no-op without error', () {
        const defaultObserver = DefaultObserver();
        // Just calling them to verify no crash (covers the empty bodies)
        defaultObserver.onRegister(0, 's', 'k', LevitDependency(),
            source: 'src');
        defaultObserver.onResolve(0, 's', 'k', LevitDependency(),
            source: 'src');
        defaultObserver.onDelete(0, 's', 'k', LevitDependency(), source: 'src');
      });
    });
  });
}
