import 'package:levit_reactive/levit_reactive.dart';
import 'package:levit_reactive/spi.dart';
import 'package:test/test.dart';

class SetOnlyMiddleware extends LevitReactiveMiddleware {
  int setCallCount = 0;

  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
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

    test('init hook stays inactive when only SetOnlyMiddleware is added', () {
      expect(LxSpi.hasInitMiddlewares, isFalse);

      final mw = SetOnlyMiddleware();
      Lx.addMiddleware(mw);

      expect(LxSpi.hasInitMiddlewares, isFalse);
      final value = 0.lx;
      value.value = 1;
      expect(mw.setCallCount, 1);
    });

    test('init hook activates only when InitOnlyMiddleware is added', () {
      expect(LxSpi.hasInitMiddlewares, isFalse);
      expect(LxSpi.hasListenerMiddlewares, isFalse);

      final mw = InitOnlyMiddleware();
      Lx.addMiddleware(mw);

      expect(LxSpi.hasInitMiddlewares, isTrue);
      expect(LxSpi.hasListenerMiddlewares, isFalse);
      final _ = 0.lx;
      expect(mw.initCallCount, 1);
    });
  });
}
