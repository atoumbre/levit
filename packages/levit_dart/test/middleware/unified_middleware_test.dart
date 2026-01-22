import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestMiddleware extends LevitMiddleware {
  int registerCount = 0;
  int stateChangeCount = 0;
  int injectionCount = 0;

  @override
  void onReactiveRegister(LxReactive reactive, String ownerId) {
    registerCount++;
  }

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          stateChangeCount++;
        };
      };

  @override
  S Function() onCreate<S>(S Function() builder, LevitScope scope, String key,
      LevitDependency info) {
    injectionCount++;
    return builder;
  }
}

void main() {
  group('Unified Middleware', () {
    late TestMiddleware middleware;

    setUp(() {
      middleware = TestMiddleware();
      Levit.addMiddleware(middleware);
    });

    tearDown(() {
      Levit.removeMiddleware(middleware);
      Levit.reset(force: true);
    });

    test('receives registration events', () {
      final rx = 0.lx.named('test').register('owner');
      rx.value++;
      expect(middleware.registerCount, equals(1));
    });

    test('receives state change events', () {
      final rx = 0.lx;
      rx.value++;
      expect(middleware.stateChangeCount, equals(1));
    });

    test('receives injection events', () {
      Levit.put(() => 'test');
      expect(middleware.injectionCount, equals(1));
    });
  });
}
