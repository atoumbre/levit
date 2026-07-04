import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ErrorCaptureMiddleware extends LevitReactiveMiddleware {
  Object? lastError;
  LxReactive? lastContext;
  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError =>
      (e, s, c) {
        lastError = e;
        lastContext = c;
      };
}

void main() {
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
}
