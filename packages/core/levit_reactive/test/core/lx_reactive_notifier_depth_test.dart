import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  test('LevitReactiveNotifier graphDepth getter and setter', () {
    final reactive = 0.lx;
    LxSpi.setGraphDepth(reactive, 10);
    expect(reactive.graphDepth, 10);
  });
}
