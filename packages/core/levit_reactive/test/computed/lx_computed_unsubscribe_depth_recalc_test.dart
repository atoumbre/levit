import 'dart:mirrors';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('_unsubscribeFrom default branch recalculates graph depth', () {
    final source = 0.lx;
    final mid = (() => source.value + 1).lx;
    final computed = (() => mid.value + 1).lx;
    final sub = computed.listen((_) {});

    expect(computed.value, 2);
    final beforeDepth = computed.graphDepth;

    final mirror = reflect(computed);
    final lib = mirror.type.owner as LibraryMirror;
    final symbol = MirrorSystem.getSymbol('_unsubscribeFrom', lib);

    mirror.invoke(symbol, [mid]);

    expect(computed.graphDepth, lessThanOrEqualTo(beforeDepth));

    sub.close();
  });
}
