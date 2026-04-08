import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class GapTestObserver extends LevitReactiveMiddleware {
  int initCount = 0;
  @override
  void Function(LxReactive)? get onInit => (r) => initCount++;
}

void main() {
  test('LxStream constructor calls observer.onInit', () {
    final obs = GapTestObserver();
    Lx.addMiddleware(obs);
    addTearDown(() => Lx.removeMiddleware(obs));

    LxStream<int>.idle();
    expect(obs.initCount, 1);
  });
}
