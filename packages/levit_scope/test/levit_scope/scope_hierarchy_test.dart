import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

// Test interface
abstract class Service {
  String get name;
}

class RootService implements Service {
  @override
  String get name => 'Root';
}

class ScopeService implements Service {
  @override
  String get name => 'Scope';
}

class Counter implements LevitScopeDisposable {
  final String id;
  bool closed = false;

  Counter(this.id);

  @override
  void onInit() {}

  @override
  void onClose() {
    closed = true;
  }

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
}

void main() {
  late LevitScope levit;

  setUp(() {
    levit = LevitScope.root();
  });

  group('Unified Scope Hierarchy', () {
    test('Root Scope Basic Operations', () {
      levit.put<Service>(() => RootService());
      expect(levit.find<Service>().name, 'Root');
      expect(levit.isRegistered<Service>(), isTrue);

      levit.delete<Service>();
      expect(levit.isRegistered<Service>(), isFalse);
    });

    test('Scope Hierarchy Resolution', () {
      levit.put<Service>(() => RootService());

      final scope = levit.createScope('child');

      // Should find in parent (root)
      expect(scope.find<Service>().name, 'Root');

      // Override in scope
      scope.put<Service>(() => ScopeService());

      // Should find local
      expect(scope.find<Service>().name, 'Scope');

      // Root should still have original
      expect(levit.find<Service>().name, 'Root');
    });

    test('Nested Scopes', () {
      final scope1 = levit.createScope('scope1');
      scope1.put(() => Counter('c1'));

      final scope2 = scope1.createScope('scope2');

      // Should resolve from parent scope
      expect(scope2.find<Counter>().id, 'c1');
    });

    test('Async Methods in Scopes', () async {
      final scope = levit.createScope('async_scope');

      // putAsync in scope -> put (simulated)
      scope.put<Service>(() => ScopeService());
      expect(await scope.findAsync<Service>(), isA<ScopeService>());

      // lazyPutAsync in scope
      scope.lazyPutAsync<Counter>(() async => Counter('async_c'), tag: 'lazy');
      expect((await scope.findAsync<Counter>(tag: 'lazy')).id, 'async_c');
    });

    test('Scope Cleanup', () {
      final scope = levit.createScope('cleanup');
      final c1 = Counter('c1');
      scope.put(() => c1);

      scope.reset();
      expect(c1.closed, isTrue);
      expect(scope.isRegistered<Counter>(), isFalse);
    });

    test('SimpleDI Delegation Check', () {
      // White-box test to ensure SimpleDI delegates correctly
      levit.put(() => Counter('root'));
      expect(levit.registeredCount, 1);
      expect(levit.registeredKeys, contains(contains('Counter')));
    });

    test('Async Resolution Cache', () async {
      // Setup: Parent with async service, Child scope
      final parent = levit.createScope('parent');
      parent.put<Service>(() => ScopeService());

      final child = parent.createScope('child');

      // 1. Uncached lookup from child (hits parent fallback logic)
      final instance1 = await child.findOrNullAsync<Service>();
      expect(instance1, isNotNull);
      expect(instance1!.name, 'Scope');

      // 2. Cached lookup from child (hits resolution cache logic)
      // The first lookup should have cached the parent scope as the provider
      final instance2 = await child.findOrNullAsync<Service>();
      expect(instance2, same(instance1));

      // 3. Verify it used the cache (white-box assumption based on code path)
      // To strictly prove it HIT the cache lines, we rely on coverage report.
    });

    test('Deep Scope Cache Path Compression', () async {
      // Grandparent -> Parent -> Child
      // Service in Grandparent
      final gp = levit.createScope('gp');
      gp.put<Service>(() => RootService());

      final parent = gp.createScope('parent');
      final child = parent.createScope('child');

      // 1. Parent finds it, caching GP
      await parent.findAsync<Service>();

      // 2. Child finds it.
      // Should see Parent has it cached, and copy that reference (path compression).
      // This hits lines 407-409 in findOrNullAsync
      final instance = await child.findOrNullAsync<Service>();
      expect(instance!.name, 'Root');
    });

    test('lazyPut with isFactory', () {
      int factoryCount = 0;
      levit.lazyPut<Service>(() {
        factoryCount++;
        return ScopeService();
      }, isFactory: true);

      final s1 = levit.find<Service>();
      final s2 = levit.find<Service>();

      expect(s1, isNot(same(s2)));
      expect(factoryCount, 2);
    });
  });
}
