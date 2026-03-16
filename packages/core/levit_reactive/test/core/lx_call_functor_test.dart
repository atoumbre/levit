import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('Lx call() functor', () {
    final rx = LxInt(0);
    expect(rx(), 0);
    rx.value = 1;
    expect(rx.call(), 1);

    final rx2 = 0.lx;
    expect(rx2(), 0);

    final dep = 0.lx;
    final computed = LxComputed(() => dep.value * 2);
    expect(computed(), 0);
  });
}
