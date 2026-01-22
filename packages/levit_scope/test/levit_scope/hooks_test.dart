import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  group('Levit Hooks', () {
    late LevitScope levit;

    setUp(() {
      levit = LevitScope.root();
    });

    test('LevitScopeMiddleware.onCreate works', () {
      bool hookCalled = false;

      S Function() myHook<S>(S Function() builder, LevitScope scope, String key,
          LevitDependency info) {
        return () {
          hookCalled = true;
          return builder();
        };
      }

      final observer = _TestCreateObserver(myHook);

      LevitScope.addMiddleware(observer);
      levit.lazyPut(() => 'test', isFactory: true);
      levit.find<String>();

      expect(hookCalled, isTrue);
      LevitScope.removeMiddleware(observer);
    });

    test('Multiple observers run in order', () {
      final order = <String>[];

      // Observer 1
      S Function() hook1<S>(S Function() builder, LevitScope scope, String key,
          LevitDependency info) {
        return () {
          order.add('Hook1 Start');
          final result = builder();
          order.add('Hook1 End');
          return result;
        };
      }

      final obs1 = _TestCreateObserver(hook1);

      // Observer 2
      S Function() hook2<S>(S Function() builder, LevitScope scope, String key,
          LevitDependency info) {
        return () {
          order.add('Hook2 Start');
          final result = builder();
          order.add('Hook2 End');
          return result;
        };
      }

      final obs2 = _TestCreateObserver(hook2);

      LevitScope.addMiddleware(obs1);
      LevitScope.addMiddleware(obs2);

      levit.lazyPut(() => 'test', isFactory: true);
      levit.find<String>();

      // Since obs2 is added AFTER obs1...
      // Original Builder
      // Wrapped 1 = Hook1(Original)
      // Wrapped 2 = Hook2(Wrapped 1)
      expect(order, [
        'Hook2 Start',
        'Hook1 Start',
        'Hook1 End',
        'Hook2 End',
      ]);

      LevitScope.removeMiddleware(obs1);
      LevitScope.removeMiddleware(obs2);
    });

    test('removeMiddleware works', () {
      bool hookCalled = false;

      S Function() myHook<S>(S Function() builder, LevitScope scope, String key,
          LevitDependency info) {
        return () {
          hookCalled = true;
          return builder();
        };
      }

      final observer = _TestCreateObserver(myHook);

      LevitScope.addMiddleware(observer);
      LevitScope.removeMiddleware(observer);

      levit.lazyPut(() => 'test', isFactory: true);
      levit.find<String>();

      expect(hookCalled, isFalse);
    });
  });
}

class _TestCreateObserver extends LevitScopeMiddleware {
  final S Function() Function<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) hook;

  const _TestCreateObserver(this.hook);

  @override
  S Function() onCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) {
    return hook<S>(builder, scope, key, info);
  }
}
