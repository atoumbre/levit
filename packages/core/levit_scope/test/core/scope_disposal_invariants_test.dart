import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope disposal invariants', () {
    test('reset(force: true) then dispose closes dependency exactly once', () {
      final scope = LevitScope.root('cleanup_once_scope');
      final probe = _DisposeProbe();

      scope.put(() => probe);
      scope.reset(force: true);
      scope.dispose();

      expect(probe.closeCount, 1);
    });

    test(
        'child disposal does not leak to parent and does not affect parent ownership',
        () {
      final root = LevitScope.root('root_scope');
      final parentProbe = _DisposeProbe();
      root.put<_DisposeProbe>(() => parentProbe, tag: 'parent');

      final child = root.createScope('child_scope');
      final childProbe = _DisposeProbe();
      child.put<_DisposeProbe>(() => childProbe, tag: 'child_local');

      expect(child.find<_DisposeProbe>(tag: 'parent'), same(parentProbe));
      expect(
          () => root.find<_DisposeProbe>(tag: 'child_local'), throwsException);

      child.dispose();

      expect(childProbe.closeCount, 1);
      expect(parentProbe.closeCount, 0);
      expect(root.find<_DisposeProbe>(tag: 'parent'), same(parentProbe));
      expect(
          () => root.find<_DisposeProbe>(tag: 'child_local'), throwsException);
    });

    test(
        'scope override isolation keeps parent instance intact after child disposal',
        () {
      final root = LevitScope.root('override_root');
      final rootProbe = _DisposeProbe();
      root.put<_DisposeProbe>(() => rootProbe, tag: 'shared');

      final child = root.createScope('override_child');
      final childProbe = _DisposeProbe();
      child.put<_DisposeProbe>(() => childProbe, tag: 'shared');

      expect(root.find<_DisposeProbe>(tag: 'shared'), same(rootProbe));
      expect(child.find<_DisposeProbe>(tag: 'shared'), same(childProbe));

      child.dispose();

      expect(childProbe.closeCount, 1);
      expect(root.find<_DisposeProbe>(tag: 'shared'), same(rootProbe));
      expect(rootProbe.closeCount, 0);

      root.dispose();
      expect(rootProbe.closeCount, 1);
    });
  });
}

class _DisposeProbe extends LevitScopeDisposable {
  int closeCount = 0;

  @override
  void onClose() {
    closeCount++;
  }
}
