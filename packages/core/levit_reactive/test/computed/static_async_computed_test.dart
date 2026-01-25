import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Static LxAsyncComputed', () {
    test('Initialization tracks dependencies correctly', () async {
      final a = 10.lx;
      final c = LxAsyncComputed(() async => a.value * 2, staticDeps: true);

      // Must listen to activate
      c.addListener(() {});

      // Value is computed asynchronously
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 20);

      // Update dependency
      a.value = 5;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 10);
    });

    test('lxStatic extension creates static async computed', () async {
      final a = 10.lx;

      // Async function
      final c = (() async => a.value * 2).lxStatic;
      c.addListener(() {});

      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 20);

      a.value = 5;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 10);
    });

    test('STATIC nature: ignores new dependencies in branch switch', () async {
      final switchVar = true.lx;
      final a = 10.lx;
      final b = 20.lx;

      final c = LxAsyncComputed(() async {
        if (switchVar.value) {
          return a.value;
        } else {
          return b.value;
        }
      }, staticDeps: true);

      // Keep it alive
      c.addListener(() {});

      // Run 1: switch=true -> deps: [switchVar, a]
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 10);

      // Update 'a' -> should update
      a.value = 15;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 15);

      // Switch branch -> recomputes, returns b.value
      switchVar.value = false;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 20);

      // CRITICAL: Update 'b' -> should NOT update (static graph locked to [switchVar, a])
      b.value = 999;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 20);

      // Update 'a' -> triggers recompute (even though unused in current branch)
      // Recompute sees switch=false, returns b.value (999)
      a.value = 0;
      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 999);
    });

    test('STATIC nature: skips cleanup overhead', () async {
      // Ideally we'd test internal state, but behaviorally:
      // If cleanup was skipped, old subscriptions persist.
      // This matches the "ignores new deps" test essentially.

      // Just verify simple stable update works repeatedly
      final a = 1.lx;
      final c = LxAsyncComputed(() async => a.value, staticDeps: true);
      c.addListener(() {});

      await Future.delayed(Duration.zero);
      expect(c.value.lastValue, 1);

      for (int i = 0; i < 5; i++) {
        a.value++;
        await Future.delayed(Duration.zero);
        expect(c.value.lastValue, 1 + i + 1);
      }
    });
  });
}
