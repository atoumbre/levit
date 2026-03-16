import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed batch update deferral', () {
    final dep = 0.lx;
    final computed = LxComputed(() => dep.value * 2);
    expect(computed.value, 0);

    bool notified = false;
    computed.addListener(() => notified = true);

    Lx.batch(() { dep.value = 1; });
    expect(notified, isTrue);
  });
}
