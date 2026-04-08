import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _MockMiddleware extends LevitReactiveMiddleware {
  bool removeListenerCalled = false;
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening =>
      (r, c) => removeListenerCalled = true;
}

void main() {
  test('cleanupSubscriptions notifies middleware on removeListener', () {
    final middleware = _MockMiddleware();
    LevitReactiveMiddleware.add(middleware);
    addTearDown(() => LevitReactiveMiddleware.remove(middleware));

    final s = 0.lx;
    final enable = true.lx;
    final c = (() => enable.value ? s.value : -1).lx;

    final sub = c.listen((_) {});
    middleware.removeListenerCalled = false;
    enable.value = false;

    expect(middleware.removeListenerCalled, isTrue);
    sub.close();
  });
}
