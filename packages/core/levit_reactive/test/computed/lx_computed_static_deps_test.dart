import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed staticDeps success', () {
    final v1 = LxVar(1);
    final c1 = LxComputed(() => v1.value + 10, staticDeps: true);
    expect(c1.value, 11);
    v1.value = 2;
    expect(c1.value, 12);
  });

  test('LxComputed staticDeps coverage (Active)', () {
    final v = 0.lx;
    final c = LxComputed(() => v.value + 1, staticDeps: true);
    c.addListener(() {});
    expect(c.value, 1);
    v.value = 10;
    expect(c.value, 11);
  });
}