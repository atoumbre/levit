import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'dart:async';

void main() {
  group('levit_reactive extended coverage', () {
    test('LxFuture wait works', () async {
      final waiting = LxFuture<int>(Future.value(1));
      final val = await waiting.wait;
      expect(val, 1);

      final error = LxFuture<int>(Future.error('err'));
      expect(() => error.wait, throwsA('err'));

      waiting.dispose();
      error.dispose();
    });

    test('LevitReactiveNotifier graphDepth getter and setter', () {
      final reactive = 0.lx;
      reactive.graphDepth = 10;
      expect(reactive.graphDepth, 10);
      reactive.close();
    });

    test('LxComputed re-entrant and updates (Active)', () {
      final source = 0.lx;
      late LxComputed<int> computed;

      computed = LxComputed(() {
        if (source.value == 1) {
          // This call should return super.value (stale) because _isComputing is true
          return computed.value;
        }
        return source.value;
      });

      final sub = computed.stream.listen((_) {});
      expect(computed.value, 0);

      source.value = 1;
      expect(computed.value, 0);

      sub.cancel();
      source.close();
      computed.close();
    });

    test('_DependencyTracker Set mode transition', () {
      final manySources = List.generate(20, (i) => i.lx);
      final bigComputed = LxComputed(() {
        return manySources.map((s) => s.value).reduce((a, b) => a + b);
      });

      expect(bigComputed.value, 190); // sum(0..19) = 19*20/2 = 190

      manySources[0].value = 10;
      expect(bigComputed.value, 200);

      // Hit _useSet = true branch in _add
      manySources[1].value = 10;
      expect(bigComputed.value, 209);

      for (var s in manySources) {
        s.close();
      }
      bigComputed.close();
    });

    test('Middleware Chain coverage', () {
      // Trigger LevitStateMiddlewareChain._()
      final m1 = TestMiddleware();
      final m2 = TestMiddleware();
      LevitReactiveMiddleware.add(m1);
      LevitReactiveMiddleware.add(m2);

      final reactive = 0.lx;
      reactive.value = 1;

      LevitReactiveMiddleware.remove(m1);
      LevitReactiveMiddleware.remove(m2);
      reactive.close();
    });
  });
}

class TestMiddleware extends LevitReactiveMiddleware {
  @override
  LxOnSet? get onSet => (next, reactive, change) => (value) {
        next(value);
      };
}
