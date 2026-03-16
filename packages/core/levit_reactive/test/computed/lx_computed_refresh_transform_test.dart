import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('LxComputed refresh and transform', () {
    final c1 = 0.lx;
    final computed = LxComputed(() => c1.value);
    computed.refresh();
    expect(computed.value, 0);

    final sub = computed.stream.listen((_) {});
    computed.refresh();
    sub.cancel();

    final transformed = computed.transform((s) => s.map((v) => v));
    expect(transformed, isA<LxStream>());
  });
}
