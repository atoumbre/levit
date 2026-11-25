import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/spi.dart';

void main() {
  group('Levit facade delegates reactive configuration and operations', () {
    test('Levit.captureStackTrace getter/setter', () {
      final original = Levit.captureStackTrace;
      Levit.captureStackTrace = !original;
      expect(Levit.captureStackTrace, !original);
      Levit.captureStackTrace = original;
    });

    test('Levit.enableWatchMonitoring getter/setter', () {
      final original = Levit.enableWatchMonitoring;
      Levit.enableWatchMonitoring = !original;
      expect(Levit.enableWatchMonitoring, !original);
      Levit.enableWatchMonitoring = original;
    });

    test('Levit.batch proxies to Lx.batch', () {
      bool called = false;
      Levit.batch(() {
        called = true;
      });
      expect(called, isTrue);
    });

    test('Levit.batchAsync proxies to Lx.batchAsync', () async {
      bool called = false;
      await Levit.batchAsync(() async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('Levit.runWithoutStateMiddleware proxies', () {
      var executed = false;
      Levit.runWithoutStateMiddleware(() {
        executed = true;
      });
      expect(executed, isTrue);
    });

    test('Levit.containsStateMiddleware proxies', () {
      expect(Levit.containsStateMiddleware(TestMiddleware()), isFalse);
    });

    test('Levit.clearStateMiddlewares proxies', () {
      final mw = TestMiddleware();
      Levit.addStateMiddleware(mw);
      expect(Levit.containsStateMiddleware(mw), isTrue);
      Levit.clearStateMiddlewares();
      expect(Levit.containsStateMiddleware(mw), isFalse);
    });

    test('LxSpi.runWithContext proxies', () {
      final context = LxListenerContext(type: 'test', id: 1, data: null);
      final result = LxSpi.runWithContext(context, () => 'done');
      expect(result, 'done');
    });

    test('RxNamingExtension.register works', () {
      final rx = 0.lx.ownedBy('owner');
      expect(rx.ownerId, 'owner');
    });
  });
}

class TestMiddleware extends LevitReactiveMiddleware {
  // Use identity equality for contains check
}
