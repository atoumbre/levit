import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ErrorCaptureMiddleware extends LevitReactiveMiddleware {
  Object? lastError;
  StackTrace? lastStack;
  LxReactive? lastContext;

  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
      get onReactiveError => (e, s, c) {
            lastError = e;
            lastStack = s;
            lastContext = c;
          };
}

void main() {
  group('Reactive Coverage Gaps', () {
    test('LxComputed staticDeps coverage', () {
      final v = 0.lx;
      final c = LxComputed(() => v.value + 1, staticDeps: true);
      c.addListener(() {}); // Make it active to hit _recompute paths

      expect(c.value, 1);

      v.value = 10;
      expect(c.value, 11);
    });

    test('LxBase _notifyListeners error middleware coverage', () {
      final middleware = ErrorCaptureMiddleware();
      Lx.addMiddleware(middleware);

      final v = 0.lx;
      v.addListener(() {
        throw Exception('listener error');
      });

      v.value = 1;

      expect(middleware.lastError.toString(), contains('listener error'));
      expect(middleware.lastContext, v);

      Lx.removeMiddleware(middleware);
    });

    test('LxAsyncComputed staticDeps coverage', () async {
      final v = 0.lx;
      final c = LxComputed.async(() async {
        return v.value + 1;
      }, staticDeps: true);

      c.addListener(() {}); // Make it active

      expect(await c.wait, 1);

      v.value = 10;
      await Future.delayed(
          Duration(milliseconds: 10)); // Wait for async recompute
      expect(await c.wait, 11);
    });
  });
}
