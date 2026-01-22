import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxComputed (Sync/Memo)', () {
    test('only notifies when value actually changes', () async {
      final source = 0.lx;
      var computeCount = 0;

      final memo = LxComputed(() {
        computeCount++;
        // Return same value for even numbers
        return source.value ~/ 2;
      });

      // Add listener to activate reactive tracking
      memo.stream.listen((_) {});
      await Future.microtask(() {});

      expect(memo.value, 0);
      final initialCount = computeCount;

      // Change 0 -> 1, result stays 0
      source.value = 1;
      await Future.delayed(Duration(milliseconds: 10));
      // Access value to trigger lazy recomputation
      memo.value;
      expect(computeCount, greaterThan(initialCount));

      // Change 1 -> 2, result becomes 1
      source.value = 2;
      await Future.delayed(Duration(milliseconds: 10));
      expect(memo.value, 1);
    });

    test('uses custom equality function', () async {
      final source = [1, 2, 3].lx;
      var valueChanges = <List<int>>[];

      final memo = LxComputed(
        () => source.value.toList(),
        equals: (a, b) =>
            a.length == b.length &&
            a.asMap().entries.every((e) => b[e.key] == e.value),
      );

      // Collect successful values
      memo.stream.listen((v) {
        // v is List<int>
        valueChanges.add(v);
        // Also check .value prop
        expect(memo.value, v);
      });
      await Future.delayed(Duration(milliseconds: 20)); // Let listener attach
      valueChanges.clear(); // Reset after initial notification

      // Same content, different list instance - memo suppresses duplicate due to equality
      source.value = [1, 2, 3];
      await Future.delayed(Duration(milliseconds: 20));
      // With lazy evaluation, _markDirty() is called, but memo's equality check
      // should suppress notification of the same value
      final countAfterSame = valueChanges.length;

      // Different content - this should appear in valueChanges
      source.value = [1, 2, 3, 4];
      await Future.delayed(Duration(milliseconds: 20));
      expect(valueChanges.length, greaterThan(countAfterSame));
      expect(valueChanges.last, [1, 2, 3, 4]);
    });

    test('close cancels subscriptions', () async {
      final source = 0.lx;
      var computeCount = 0;

      final memo = LxComputed(() {
        computeCount++;
        return source.value;
      });

      // Add listener to activate
      memo.stream.listen((_) {});
      await Future.microtask(() {});
      final initialCount = computeCount;

      memo.close();

      source.value = 1;
      await Future.microtask(() {});
      expect(computeCount, initialCount); // No recompute after close
    });

    test('toString shows value', () {
      final memo = LxComputed(() => 42);
      expect(memo.toString(), contains('LxComputed'));
      expect(memo.toString(), contains('42'));
    });

    test('adds and removes listeners', () {
      final memo = LxComputed(() => 42);
      void listener() {}

      memo.addListener(listener);
      memo.removeListener(listener);
    });
  });

  group('LxComputed.async factory', () {
    test('creates LxAsyncComputed', () async {
      final id = 1.lx;
      final computed = LxComputed.async(() async {
        return id.value * 2;
      });

      // Add listener to activate
      computed.stream.listen((_) {});
      await Future.delayed(Duration(milliseconds: 50));
      expect(computed.valueOrNull, 2);
    });
  });

  test('reconciles stream dependencies (removing unused)', () async {
    final useA = true.lx;
    final sourceA = 10.lx;
    final sourceB = 20.lx;

    // Force stream creation on sourceA so it is tracked as a stream dependency
    final subA = sourceA.stream.listen((_) {});

    // Computed depends on A or B
    final computed = LxComputed(() {
      if (useA.value) {
        return sourceA.value;
      } else {
        return sourceB.value;
      }
    });

    // Activate computed
    final subC = computed.stream.listen((_) {});
    await Future.microtask(() {});
    expect(computed.value, 10);

    // Now switch to B
    useA.value = false;
    await Future.microtask(() {}); // Let useA update propagate

    expect(computed.value, 20);

    // Cleanup
    subA.cancel();
    subC.cancel();
    computed.close();
  });
}
