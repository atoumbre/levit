import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('cleanupSubscriptions runs without middleware', () {
    final s = 0.lx;
    final c = (() => s.value * 2).lx;
    final sub = c.listen((_) {});
    s.value = 1;
    sub.close();
    expect(c.hasListener, isFalse);
  });
}
