import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('LevitState', () {
    test('standard functional state resolution', () {
      final counter = LevitState((ref) {
        final count = ref.autoDispose(0.lx);
        return count;
      });

      final result = counter.find();
      expect(result.value, 0);

      result.value++;
      expect(counter.find().value, 1);
    });

    test('scoped safety (isolation)', () {
      final counter = LevitState((ref) {
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

    test('reactivity via ref.watch', () {
      final dependency = 0.lx;
      var buildCount = 0;

      final state = LevitState((ref) {
        buildCount++;
        final depValue = dependency.value;
        return 'Value: $depValue';
      });

      expect(state.find(), 'Value: 0');
      expect(buildCount,
          1); // Optimized: 1 (LxComputed constructor) and no second run in _onActive

      dependency.value = 1;
      expect(state.find(), 'Value: 1');
      expect(buildCount, 2);
    });

    test('autoDispose in functional state', () {
      var disposed = false;
      final state = LevitState((ref) {
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
      final asyncState = LevitState.async((ref) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'resolved';
      });

      final result = await asyncState.findAsync();
      expect(result, 'resolved');
    });

    test('find state by key in Levit.find', () {
      final state = LevitState((ref) => 'hello');

      expect(Levit.find<String>(key: state), 'hello');
    });
  });
}
