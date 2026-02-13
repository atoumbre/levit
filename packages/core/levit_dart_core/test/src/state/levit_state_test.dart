import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('LevitStore', () {
    test('standard functional state resolution', () {
      final counter = LevitStore((ref) {
        final count = ref.autoDispose(0.lx);
        return count;
      });

      final result = counter.find();
      expect(result.value, 0);

      result.value++;
      expect(counter.find().value, 1);
    });

    test('scoped safety (isolation)', () {
      final counter = LevitStore((ref) {
        return 0.lx;
      });

      final root = LevitScope.root();
      final scopeA = root.createScope('A');
      final scopeB = root.createScope('B');

      final valA = counter.findIn(scopeA);
      final valB = counter.findIn(scopeB);

      expect(valA, isNot(same(valB)),
          reason: 'State instances must be isolated per scope');

      valA.value = 10;
      valB.value = 20;

      expect(counter.findIn(scopeA).value, 10);
      expect(counter.findIn(scopeB).value, 20);
    });

    test('autoDispose in functional state', () {
      var disposed = false;
      final state = LevitStore((ref) {
        ref.onDispose(() => disposed = true);
        return 'test';
      });

      final root = LevitScope.root();
      state.findIn(root);
      expect(disposed, false);

      root.dispose();
      expect(disposed, true);
    });

    test('async state resolution', () async {
      final asyncState = LevitStore.async((ref) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'resolved';
      });

      expect(await asyncState.find(), 'resolved');
    });

    test('find state by key in Levit.find', () {
      final state = LevitStore((ref) => 'hello');

      expect(state.find(), 'hello');
    });
  });
}
