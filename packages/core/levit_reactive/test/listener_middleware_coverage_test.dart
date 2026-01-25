import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class CoverageMiddleware extends LevitReactiveMiddleware {
  int startCount = 0;
  int stopCount = 0;
  LxListenerContext? lastContext;

  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening =>
      (r, c) {
        startCount++;
        lastContext = c;
      };

  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening =>
      (r, c) {
        stopCount++;
        lastContext = c;
      };
}

void main() {
  group('Listener Middleware Coverage', () {
    test('runWithContext logic and middleware hooks', () async {
      final mw = CoverageMiddleware();
      LevitReactiveMiddleware.add(mw);
      addTearDown(() => LevitReactiveMiddleware.remove(mw));

      expect(LevitReactiveMiddleware.hasListenerMiddlewares, isTrue);

      // 1. Test direct Lx.runWithContext
      final ctx =
          const LxListenerContext(type: 'Test', id: 1, data: {'key': 'val'});
      Lx.runWithContext(ctx, () {
        expect(Lx.proxy, isNull); // Verify it doesn't change proxy

        // So let's trigger a listener add inside the context
        final v = LxVar(0);
        v.addListener(() {});
      });

      expect(mw.startCount, 1);
      expect(mw.lastContext, equals(ctx));

      // 2. Test LxComputed subscriptions
      // LxComputed internally uses runWithContext when subscribing
      final source = LxVar(10, name: 'source');
      mw.startCount = 0;
      mw.lastContext = null;

      final computed = LxComputed(() => source.value * 2, name: 'comp');

      // LxComputed only subscribes to dependencies when it is active (has listeners)
      final dummyListener = () {};
      computed.addListener(dummyListener);

      expect(computed.value, 20);

      // Should have subscribed to 'source' WITH context provided by LxComputed
      expect(mw.startCount, greaterThan(0));
      // The context from LxComputed looks like {type: LxComputed, ...}
      expect(mw.lastContext, isNotNull);
      expect(mw.lastContext!.type, 'LxComputed');
      expect((mw.lastContext!.data as Map)['name'], 'comp');

      // 3. Test LxComputed unsubscription
      mw.stopCount = 0;
      mw.lastContext = null;

      // Removing the listener should make computed inactive, forcing it to unsubscribe from source
      computed.removeListener(dummyListener);

      // Should have unsubscribed from 'source' WITH context
      expect(mw.stopCount, greaterThan(0));
      expect(mw.lastContext, isNotNull);
      expect(mw.lastContext!.type, 'LxComputed');

      // 4. Test manual removeListener coverage
      final l = () {};
      source.addListener(l);
      mw.stopCount = 0;
      source.removeListener(l);
      // Context is null for manual calls unless wrapped
      expect(mw.stopCount, 1);
      expect(mw.lastContext, isNull);
    });

    test('runWithContext without middleware', () {
      LevitReactiveMiddleware.clear();
      expect(LevitReactiveMiddleware.hasListenerMiddlewares, isFalse);

      // Should execute immediately without setting context
      bool executed = false;
      final ctx = const LxListenerContext(type: 'Test', id: 1);
      Lx.runWithContext(ctx, () {
        executed = true;
      });
      expect(executed, isTrue);
    });
  });
}
