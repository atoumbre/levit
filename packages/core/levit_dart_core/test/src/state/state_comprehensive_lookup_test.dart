import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Comprehensive Coverage', () {
    setUp(() {
      Levit.enableAutoLinking();
    });

    tearDown(() {
      Levit.disableAutoLinking();
      Levit.reset(force: true);
    });

    test('LevitStore and LevitRef coverage', () async {
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

      expect(await asyncState.findAsync(), 'async_dep');
      expect(asyncState.toString(), contains('LevitAsyncStore'));
    });

    test('Levit core find methods coverage', () async {
      // findOrNull
      Levit.put(() => 'val', tag: 'val_tag');
      expect(Levit.findOrNull<String>(tag: 'val_tag'), 'val');
      expect(Levit.findOrNull<String>(tag: 'missing'), isNull);

      // findAsync
      Levit.lazyPutAsync(() async => 'aval', tag: 'aval_tag');
      expect(await Levit.findAsync<String>(tag: 'aval_tag'), 'aval');

      // findOrNullAsync
      expect(await Levit.findOrNullAsync<String>(tag: 'aval_tag'), 'aval');
      expect(await Levit.findOrNullAsync<String>(tag: 'missing_async'), isNull);

      // isRegistered and isInstantiated for LevitStore
      // Hit lines 172 and 181
      final state = LevitStore<String>((ref) => 'val');
      state.find();
      state.find(tag: 'provider_test');
      expect(state.isRegisteredIn(Ls.currentScope, tag: 'provider_test'), true);
      expect(
          state.isInstantiatedIn(Ls.currentScope, tag: 'provider_test'), true);

      // delete
      expect(state.delete(), true);
      expect(state.delete(), false); // Already deleted
    });

    test('Auto-linking and adoption coverage', () {
      final state = LevitStore<LxVar<int>>((ref) {
        final v = 0.lx;
        return v;
      });

      final v = state.find(tag: 'tag1');
      expect(v.ownerId, contains('tag1'));
    });

    test('LevitRef dispose error log coverage', () {
      final state = LevitStore((ref) {
        ref.onDispose(() => throw Exception('onDispose error'));
        return 'test';
      });
      state.find();
      Levit.reset(force: true);
    });

    test('Coverage for private/internal paths', () {
      // runCapturedForTesting is already covered by its own tests or we can add here
    });

    test('LevitStoreExtension coverage', () async {
      final state = LevitStore((ref) => 'test');
      expect(state.find(), 'test');

      // findAsync extension (state.dart line 325)
      expect(await state.findAsync(), 'test');

      // delete extension (state.dart lines 329-330)
      expect(state.delete(), true);
      expect(state.delete(), false);
    });

    test('Chained capture and nested put coverage', () {
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
