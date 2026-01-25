import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

class _CountingMiddleware implements LevitReactiveMiddleware {
  int onChangeCount = 0;

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          onChangeCount++;
          next(value);
        };
      };

  @override
  LxOnBatch? get onBatch => null;

  @override
  LxOnDispose? get onDispose => null;

  @override
  void Function(LxReactive)? get onInit => null;
  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening => null;

  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError => null;
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
        Levit.addStateMiddleware(m);
      }

      final source = (-1).lx;

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
        Levit.removeStateMiddleware(m);
      }
      source.close();
    });
  });
}
