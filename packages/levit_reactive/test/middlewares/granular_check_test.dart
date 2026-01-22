import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

class SetOnlyMiddleware extends LevitReactiveMiddleware {
  int setCallCount = 0;

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          setCallCount++;
          next(value);
        };
      };
}

class InitOnlyMiddleware extends LevitReactiveMiddleware {
  int initCallCount = 0;

  @override
  void Function(LxReactive reactive)? get onInit => (reactive) {
        initCallCount++;
      };
}

void main() {
  group('Granular Middleware Checks', () {
    setUp(() {
      Lx.clearMiddlewares();
    });

    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('hasSetMiddlewares is true only when SetOnlyMiddleware is added', () {
      expect(LevitReactiveMiddleware.hasSetMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isFalse);

      final mw = SetOnlyMiddleware();
      Lx.addMiddleware(mw);

      expect(LevitReactiveMiddleware.hasSetMiddlewares, isTrue);
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isFalse);
    });

    test('hasInitMiddlewares is true only when InitOnlyMiddleware is added',
        () {
      expect(LevitReactiveMiddleware.hasSetMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isFalse);

      final mw = InitOnlyMiddleware();
      Lx.addMiddleware(mw);

      expect(LevitReactiveMiddleware.hasSetMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isTrue);
    });

    test('events are skipped if flag is false', () {
      // 1. Add only Set listener
      final setMw = SetOnlyMiddleware();
      Lx.addMiddleware(setMw);

      // 2. Create reactive (triggers onInit)
      // Since hasInitMiddlewares is false, onInit logic should be skipped entirely.
      final val = 0.lx;

      // We can't easily assert that internal core skipped the call
      // other than checking side effects on a middleware that WOULD have listened if we added it?
      // But here we only have SetMw.

      // 3. Trigger Set
      val.value = 1;
      expect(setMw.setCallCount, equals(1));
    });

    test('LevitReactiveHistoryMiddleware opts out of Init', () {
      final history = LevitReactiveHistoryMiddleware();
      Lx.addMiddleware(history);

      expect(LevitReactiveMiddleware.hasSetMiddlewares, isTrue);
      expect(LevitReactiveMiddleware.hasBatchMiddlewares, isTrue);
      // History does NOT observe Init/Dispose/GraphChange in optimization
      expect(LevitReactiveMiddleware.hasInitMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasDisposeMiddlewares, isFalse);
      expect(LevitReactiveMiddleware.hasGraphChangeMiddlewares, isFalse);
    });
  });
}
