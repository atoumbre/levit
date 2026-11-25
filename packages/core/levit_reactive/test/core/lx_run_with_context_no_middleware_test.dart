import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  test('runWithContext without middleware', () {
    LevitReactiveMiddleware.clear();
    bool executed = false;
    LxSpi.runWithContext(const LxListenerContext(type: 'Test', id: 1), () {
      executed = true;
    });
    expect(executed, isTrue);
  });
}
