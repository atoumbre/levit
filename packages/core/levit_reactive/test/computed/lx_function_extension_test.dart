import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxFunctionExtension creates computed', () {
    final c1 = 10.lx;
    final computed = (() => c1.value * 2).lx;
    expect(computed.value, 20);
  });
}
