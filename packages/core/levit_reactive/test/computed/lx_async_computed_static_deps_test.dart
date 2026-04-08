import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxAsyncComputed staticDeps async success', () async {
    final v1 = LxVar(1);
    final c1 = LxAsyncComputed(() async => v1.value + 20, staticDeps: true);
    expect((await c1.stream.firstWhere((s) => s.hasValue)).valueOrNull, 21);
    v1.value = 2;
    expect((await c1.stream.firstWhere((s) => s.hasValue)).valueOrNull, 22);
  });

  test('LxAsyncComputed staticDeps coverage (Active)', () async {
    final v = 0.lx;
    final c = LxComputed.async(() async {
      return v.value + 1;
    }, staticDeps: true);
    c.addListener(() {});
    expect(await c.wait, 1);
    v.value = 10;
    await Future.delayed(Duration(milliseconds: 10));
    expect(await c.wait, 11);
  });
}
