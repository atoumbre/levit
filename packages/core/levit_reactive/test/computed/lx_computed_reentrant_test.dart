import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('LxComputed re-entrant and updates (Active)', () {
    final source = 0.lx;
    late LxComputed<int> computed;

    computed = LxComputed(() {
      if (source.value == 1) return computed.value;
      return source.value;
    });

    final sub = computed.stream.listen((_) {});
    expect(computed.value, 0);

    source.value = 1;
    expect(computed.value, 0);

    sub.cancel();
  });
}
