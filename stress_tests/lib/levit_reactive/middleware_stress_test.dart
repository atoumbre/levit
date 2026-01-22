import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart/levit_dart.dart';

class _CountingMiddleware extends LevitMiddleware {
  int onChangeCount = 0;

  // @override
  // void onChange(LxReactive reactive, LevitReactiveChange change) {
  //   onChangeCount++;
  // }
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Stress Test: Middleware', () {
    test('Middleware Pipeline Overhead - 100 middlewares, 10k updates', () {
      print('[Description] Measures overhead of a middleware pipeline.');
      const middlewareCount = 100;
      const updates = 10000;

      final middlewares =
          List.generate(middlewareCount, (_) => _CountingMiddleware());
      for (final m in middlewares) {
        Levit.addMiddleware(m);
      }

      final source = 0.lx;

      final sw = Stopwatch()..start();
      for (var i = 0; i < updates; i++) {
        source.value = i;
      }
      sw.stop();

      final totalOnChange =
          middlewares.fold<int>(0, (sum, m) => sum + m.onChangeCount);
      print(
          'Middleware Pipeline: Processed $updates updates with $middlewareCount middlewares in ${sw.elapsedMilliseconds}ms');
      print('Total onChange calls across all middlewares: $totalOnChange');

      expect(totalOnChange, updates * middlewareCount);

      for (final m in middlewares) {
        Levit.removeMiddleware(m);
      }
      source.close();
    });
  });
}
