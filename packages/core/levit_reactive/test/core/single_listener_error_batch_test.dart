import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ErrorMiddleware extends LevitReactiveMiddleware {
  Object? lastError;
  @override void Function(Object, StackTrace?, LxReactive?)? get onReactiveError => (e, s, c) => lastError = e;
}

void main() {
  test('Single listener error via batch', () {
    final middleware = ErrorMiddleware();
    LevitReactiveMiddleware.add(middleware);

    final rx = 0.lx;
    rx.addListener(() { throw 'SingleListenerError'; });

    Lx.batch(() { rx.value = 1; });

    expect(middleware.lastError, 'SingleListenerError');
    LevitReactiveMiddleware.clear();
  });
}
