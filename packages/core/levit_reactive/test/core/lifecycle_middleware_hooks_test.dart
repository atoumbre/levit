import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class TestHistoryMiddleware extends LevitReactiveMiddleware {
  int disposeCount = 0;
  @override LxOnDispose? get onDispose => (next, reactive) => () { disposeCount++; next(); };
}

class TestObserver extends LevitReactiveMiddleware {
  int initCount = 0;
  @override void Function(LxReactive reactive)? get onInit => (reactive) => initCount++;
}

void main() {
  group('Lifecycle Hooks', () {
    late TestHistoryMiddleware mw;
    late TestObserver obs;

    setUp(() { mw = TestHistoryMiddleware(); obs = TestObserver(); Lx.addMiddleware(mw); Lx.addMiddleware(obs); });
    tearDown(() { Lx.clearMiddlewares(); });

    test('onInit/onDispose for Lx', () {
      final rx = 0.lx; expect(obs.initCount, 1);
      rx.close(); expect(mw.disposeCount, 1);
    });

    test('onInit/onDispose for LxComputed', () {
      final rx = LxComputed(() => 1); expect(obs.initCount, 1);
      rx.close(); expect(mw.disposeCount, 1);
    });

    test('onInit/onDispose for LxStream', () {
      final rx = LxStream.idle(); expect(obs.initCount, 1);
      rx.close(); expect(mw.disposeCount, 1);
    });

    test('onInit/onDispose for LxFuture', () {
      final rx = LxFuture.idle(); expect(obs.initCount, 1);
      rx.close(); expect(mw.disposeCount, 1);
    });
  });
}
