import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('Computed updates inside batch', () {
    final count = LxVar(0);
    final doubled = LxComputed(() => count.value * 2);

    // Initial value
    expect(doubled.value, 0);

    // Update inside batch
    Lx.batch(() {
      count.value++; // 1
      // Computed is marked dirty but not recomputed yet ideally?
      // Wait, inside batch, notifications are deferred.
      // But accessing .value might trigger recomputation if dirty?
      // The code path we want is _onDependencyChanged -> Lx.isBatching -> notify()

      // Let's ensure doubled is observing count.
      // Doubled already observed count on initial read.
    });

    // After batch, it should be updated
    expect(doubled.value, 2);
  });
}
