import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Static LxComputed', () {
    test('Initialization tracks dependencies correctly', () {
      final a = 10.lx;
      final c = LxComputed(() => a.value * 2, staticDeps: true);

      expect(c.value, 20);
      a.value = 5;
      expect(c.value, 10);
    });

    test('lxStatic extension creates static computed', () {
      final a = 10.lx;
      final c = (() => a.value * 2).lxStatic;

      expect(c.value, 20);
      a.value = 5;
      expect(c.value, 10);
    });

    test('updates value when dependencies change', () {
      final a = 1.lx;
      final b = 2.lx;
      final c = LxComputed(() => a.value + b.value, staticDeps: true);

      expect(c.value, 3);
      a.value = 2;
      expect(c.value, 4);
      b.value = 3;
      expect(c.value, 5);
    });

    test('STATIC nature: ignores new dependencies in branch switch', () {
      final switchVar = true.lx;
      final a = 10.lx; // Used in first run
      final b = 20.lx; // Used in second run (if dynamic)

      // Computed depends on 'switchVar' and EITHER 'a' or 'b'
      // Since staticDeps: true, it will lock the graph to [switchVar, a] after first run.
      final c = LxComputed(() {
        if (switchVar.value) {
          return a.value;
        } else {
          return b.value;
        }
      }, staticDeps: true);

      // Must be active to use dependency graph
      c.addListener(() {});

      // Initial run: switch=true -> deps: [switchVar, a]
      expect(c.value, 10);

      // Change 'a' -> should update
      a.value = 15;
      expect(c.value, 15);

      // Switch branch -> recomputes value, BUT keeps old deps [switchVar, a]
      switchVar.value = false;
      // It re-runs compute(), sees switch=false, returns b.value (20).
      expect(c.value, 20);

      // CRITICAL: Change 'b' -> should NOT update because it's not in the static graph
      b.value = 999;
      expect(c.value, 20); // Still 20, ignored 'b' update

      // Change 'a' -> should update (even though not currently used, it's in graph!)
      // Wait, if we change 'a', the dependency triggers recompute.
      // Recompute runs: returns b.value (999).
      a.value = 0;
      expect(c.value, 999); // 'a' triggered the update, which read fresh 'b'
    });

    test('STATIC nature: does not remove old dependencies', () {
      // Similar to above, verifying that 'a' remains a dependency even if unused
      final switchVar = true.lx;
      final a = 10.lx;

      final c = LxComputed(() {
        if (switchVar.value) return a.value;
        return 0;
      }, staticDeps: true);

      expect(c.value, 10);

      // Switch to branch that uses nothing
      switchVar.value = false;
      expect(c.value, 0);

      // Modify 'a' -> should still trigger recompute (useless, but proves static graph)
      // We can't easily check internal "dirty" state, but we can check side effects if we had them.
      // Instead, let's use a counter.
      // Reset switch for next test case
      switchVar.value = true;
      int computations = 0;
      final c2 = LxComputed(() {
        computations++;
        if (switchVar.value) return a.value;
        return 0;
      }, staticDeps: true);

      c2.addListener(() {});

      // Run 1
      expect(c2.value, 10);
      expect(computations, 1); // Optimized: only 1 build during initialization

      // Run 2 (switch change)
      switchVar.value = false;
      expect(c2.value, 0);
      expect(computations, 2);

      // Change 'a'. In dynamic computed, 'a' would be dropped. In static, it stays.
      // So changing 'a' should trigger a recompute.
      a.value = 99;
      // Note: c2 is dirty now, but hasn't recomputed yet (lazy).
      // Access value to trigger recompute.
      expect(c2.value, 0);
      expect(computations, 3); // Proves 'a' is still tracked
    });
  });
}
