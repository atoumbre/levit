import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class CoverageMiddleware extends LevitReactiveMiddleware {
  int startCount = 0;
  int stopCount = 0;
  LxListenerContext? lastContext;
  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening =>
      (r, c) {
        startCount++;
        lastContext = c;
      };
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening =>
      (r, c) {
        stopCount++;
        lastContext = c;
      };
}

void main() {
  test('runWithContext logic and middleware hooks', () {
    final mw = CoverageMiddleware();
    LevitReactiveMiddleware.add(mw);
    addTearDown(() => LevitReactiveMiddleware.remove(mw));

    final ctx =
        const LxListenerContext(type: 'Test', id: 1, data: {'key': 'val'});
    Lx.runWithContext(ctx, () {
      final v = LxVar(0);
      v.addListener(() {});
    });

    expect(mw.startCount, 1);
    expect(mw.lastContext, equals(ctx));

    final source = LxVar(10, name: 'source');
    mw.startCount = 0;
    mw.lastContext = null;

    final computed = LxComputed(() => source.value * 2, name: 'comp');
    final dummyListener = () {};
    computed.addListener(dummyListener);

    expect(computed.value, 20);
    expect(mw.startCount, greaterThan(0));
    expect(mw.lastContext!.type, 'LxComputed');

    mw.stopCount = 0;
    mw.lastContext = null;
    computed.removeListener(dummyListener);

    expect(mw.stopCount, greaterThan(0));
    expect(mw.lastContext!.type, 'LxComputed');
  });
}
