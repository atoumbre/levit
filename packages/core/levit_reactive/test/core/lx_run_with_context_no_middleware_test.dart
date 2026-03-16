import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('runWithContext without middleware', () {
    LevitReactiveMiddleware.clear();
    bool executed = false;
    Lx.runWithContext(const LxListenerContext(type: 'Test', id: 1), () { executed = true; });
    expect(executed, isTrue);
  });
}
