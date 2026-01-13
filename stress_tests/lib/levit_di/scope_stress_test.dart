import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart/levit_dart.dart';

class _Service {
  final int id;
  _Service(this.id);
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Stress Test: DI Scoping', () {
    test('Deep Nesting - 1000 nested scopes', () {
      print('[Description] Tests resolution through deeply nested scopes.');
      const depth = 1000;

      // Build nested scopes using createScope (creates child of root)
      final sw = Stopwatch()..start();
      LevitScope current = Levit.createScope('root');
      current.put<_Service>(() => _Service(0), tag: 'root_svc');

      for (var i = 1; i < depth; i++) {
        current = current.createScope('scope_$i');
      }
      sw.stop();
      print('Created $depth nested scopes in ${sw.elapsedMilliseconds}ms');

      // Resolve through all layers
      sw.reset();
      sw.start();
      final service = current.find<_Service>(tag: 'root_svc');
      sw.stop();

      expect(service.id, 0);
      print(
          'Resolved root dependency through $depth layers in ${sw.elapsedMilliseconds}ms');
    });

    test('Shadowing - Resolution at each level', () {
      print(
          '[Description] Tests that shadowing works correctly at all levels.');
      const depth = 100;

      LevitScope current = Levit.createScope('root');
      current.put<_Service>(() => _Service(-1), tag: 'svc');

      for (var i = 0; i < depth; i++) {
        current = current.createScope('scope_$i');
        current.put<_Service>(() => _Service(i), tag: 'svc');
      }

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final svc = current.find<_Service>(tag: 'svc');
        expect(svc.id, depth - 1);
      }
      sw.stop();

      print(
          'Performed 1000 shadowed lookups at depth $depth in ${sw.elapsedMilliseconds}ms');
    });

    test('Scope Reset Cascade', () {
      print('[Description] Tests that resetting a scope cleans up correctly.');
      final root = Levit.createScope('root');
      root.put<_Service>(() => _Service(0), tag: 'svc');

      final child = root.createScope('child');
      child.put<_Service>(() => _Service(1), tag: 'child_svc');

      // Service should be found before reset
      expect(child.find<_Service>(tag: 'svc').id, 0);

      // Reset root
      root.reset(force: true);

      // Root service should be gone
      expect(root.isRegistered<_Service>(tag: 'svc'), false);
      print('Scope reset cascade verified');
    });
  });
}
