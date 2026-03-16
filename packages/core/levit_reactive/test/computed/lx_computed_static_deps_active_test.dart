import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed staticDeps (Active)', () {
    final a = 1.lx;
    final b = 2.lx;
    final c = LxComputed(() => a.value + b.value, staticDeps: true);
    c.addListener(() {}); // Make it active

    expect(c.value, 3);
    a.value = 10;
    expect(c.value, 12);
  });
}
