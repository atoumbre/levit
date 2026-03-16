import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('LevitAsyncStore contract', () {
    tearDown(() {
      Levit.reset(force: true);
    });

    test('find APIs expose single-await Future<T> semantics', () async {
      final scope = LevitScope.root('single_await_scope');
      final store = LevitStore.async((_) async => 7);

      final Future<int> fromFind = store.find();
      final Future<int> fromFindAsync = store.findAsync();
      final Future<int> fromFindIn = store.findIn(scope);
      final Future<int> fromFindAsyncIn = store.findAsyncIn(scope);

      expect(await fromFind, 7);
      expect(await fromFindAsync, 7);
      expect(await fromFindIn, 7);
      expect(await fromFindAsyncIn, 7);
    });

    test('concurrent lookups in same scope run builder once', () async {
      final scope = LevitScope.root('concurrency_scope');
      int buildCount = 0;

      final store = LevitStore.async((_) async {
        buildCount++;
        await Future.delayed(const Duration(milliseconds: 5));
        return 'ok';
      });

      final results = await Future.wait([
        store.findIn(scope),
        store.findIn(scope),
        store.findAsyncIn(scope),
      ]);

      expect(results, ['ok', 'ok', 'ok']);
      expect(buildCount, 1);
    });

    test('failed async value is stable until store instance is deleted',
        () async {
      final scope = LevitScope.root('failure_scope');
      int buildCount = 0;

      final store = LevitStore.async((_) async {
        buildCount++;
        await Future.delayed(Duration.zero);
        throw StateError('boom-$buildCount');
      });

      await expectLater(
        store.findIn(scope),
        throwsA(
          predicate((e) => e is StateError && '$e'.contains('boom-1')),
        ),
      );

      await expectLater(
        store.findAsyncIn(scope),
        throwsA(
          predicate((e) => e is StateError && '$e'.contains('boom-1')),
        ),
      );

      expect(buildCount, 1);

      expect(store.deleteIn(scope, force: true), isTrue);

      await expectLater(
        store.findIn(scope),
        throwsA(
          predicate((e) => e is StateError && '$e'.contains('boom-2')),
        ),
      );

      expect(buildCount, 2);
    });

    test(
        'isRegistered/isInstantiated and delete helpers delegate to inner store',
        () async {
      final scope = LevitScope.root('introspection_scope');
      final store = LevitStore.async((_) async => 7);

      expect(store.isRegisteredIn(scope), isFalse);
      expect(store.isInstantiatedIn(scope), isFalse);

      expect(await store.findIn(scope), 7);
      expect(store.isRegisteredIn(scope), isTrue);
      expect(store.isInstantiatedIn(scope), isTrue);

      scope.run(() {
        // Covers LevitAsyncStore.delete() which relies on Ls.currentScope.
        expect(store.delete(force: true), isTrue);
      });

      expect(store.isRegisteredIn(scope), isFalse);
      expect(store.isInstantiatedIn(scope), isFalse);
    });
  });
}
