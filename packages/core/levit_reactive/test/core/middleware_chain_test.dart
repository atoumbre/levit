import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('Middleware Chain coverage', () {
    final m1 = _TestMiddleware();
    final m2 = _TestMiddleware();
    LevitReactiveMiddleware.add(m1);
    LevitReactiveMiddleware.add(m2);

    final reactive = 0.lx;
    reactive.value = 1;

    LevitReactiveMiddleware.remove(m1);
    LevitReactiveMiddleware.remove(m2);
  });
}

class _TestMiddleware extends LevitReactiveMiddleware {
  @override
  LxOnSet? get onSet => (next, r, c) => (v) => next(v);
}
