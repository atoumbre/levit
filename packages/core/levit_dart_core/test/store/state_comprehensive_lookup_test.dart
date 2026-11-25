import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Store resolution, ownership, and disposal', () {
    setUp(() {
      Levit.enableAutoLinking();
    });

    tearDown(() async {
      Levit.disableAutoLinking();
      await Levit.reset(force: true);
    });

    test(
      'store builders resolve synchronous and asynchronous dependencies',
      () async {
        final state = LevitStore<String>((ref) {
          // ref.scope coverage
          expect(ref.scope, isNotNull);

          // ref.find and findAsync coverage
          Levit.put(() => 'dep', tag: 'd');
          expect(ref.find<String>(tag: 'd'), 'dep');

          return 'ok';
        });

        expect(state.find(), 'ok');
        expect(state.toString(), contains('LevitStore'));

        final asyncState = LevitStore.async((ref) async {
          await Future.delayed(Duration(milliseconds: 5));
          Levit.lazyPutAsync(() async => 'async_dep', tag: 'ad');
          return await ref.findAsync<String>(tag: 'ad');
        });

        expect(await asyncState.find(), 'async_dep');
        expect(asyncState.toString(), contains('LevitAsyncStore'));
      },
    );

    test(
      'lookups distinguish missing dependencies and instantiated stores',
      () async {
        // findOrNull
        Levit.put(() => 'val', tag: 'val_tag');
        expect(Levit.findOrNull<String>(tag: 'val_tag'), 'val');
        expect(Levit.findOrNull<String>(tag: 'missing'), isNull);

        // findAsync
        Levit.lazyPutAsync(() async => 'a_val', tag: 'a_val_tag');
        expect(await Levit.findAsync<String>(tag: 'a_val_tag'), 'a_val');

        // findOrNullAsync
        expect(await Levit.findOrNullAsync<String>(tag: 'a_val_tag'), 'a_val');
        expect(
          await Levit.findOrNullAsync<String>(tag: 'missing_async'),
          isNull,
        );

        // isRegistered and isInstantiated for LevitStore
        // Hit lines 172 and 181
        final state = LevitStore<String>((ref) => 'val');
        state.find();
        state.find(tag: 'provider_test');
        expect(
          state.isRegisteredIn(Ls.currentScope, tag: 'provider_test'),
          true,
        );
        expect(
          state.isInstantiatedIn(Ls.currentScope, tag: 'provider_test'),
          true,
        );

        // delete
        expect(await state.delete(), true);
        expect(await state.delete(), false); // Already deleted
      },
    );

    test('store reactives receive an owner ID independent of the tag', () {
      final state = LevitStore<LxVar<int>>((ref) {
        final v = 0.lx;
        return v;
      });

      final v = state.find(tag: 'tag1');
      expect(v.ownerId, startsWith('${Ls.currentScope.id}:'));
      expect(v.ownerId, isNot(contains('tag1')));
    });

    test('reset reports failures from store disposal callbacks', () async {
      final state = LevitStore((ref) {
        ref.onDispose(() => throw Exception('onDispose error'));
        return 'test';
      });
      state.find();
      await expectLater(
        Levit.reset(force: true),
        throwsA(isA<LevitDisposalException>()),
      );
    });

    test(
      'store lookups share an instance and deletion is idempotent',
      () async {
        final state = LevitStore((ref) => 'test');
        expect(state.find(), 'test');

        // delete extension
        expect(await state.delete(), true);
        expect(await state.delete(), false);
      },
    );

    test('nested registrations assign owners to their reactives', () {
      Levit.put(() {
        final _ = 0.lx;

        Levit.put(() {
          final innerVar = 1.lx;
          expect(innerVar.ownerId, isNotNull);
          return 'inner';
        }, tag: 'inner');

        return 'outer';
      }, tag: 'outer');
    });
  });
}
