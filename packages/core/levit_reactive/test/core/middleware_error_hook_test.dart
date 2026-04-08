import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LevitReactiveMiddleware error hook', () {
    String? caught;
    final mw = _ErrorMiddleware((e, s, r) => caught = e.toString());
    Lx.addMiddleware(mw);
    final v1 = LxVar(1);
    v1.addListener(() {
      throw 'listener_error';
    });
    v1.value = 2;
    expect(caught, 'listener_error');
    Lx.removeMiddleware(mw);
  });
}

class _ErrorMiddleware extends LevitReactiveMiddleware {
  final void Function(Object e, StackTrace? s, LxReactive? r) onError;
  _ErrorMiddleware(this.onError);
  @override
  void Function(Object e, StackTrace? s, LxReactive? r)? get onReactiveError =>
      onError;
}
