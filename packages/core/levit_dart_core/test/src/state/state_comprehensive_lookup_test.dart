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

    test('LevitState and LevitRef coverage', () async {
      final state = LevitState<String>((ref) {
        // ref.scope coverage
        expect(ref.scope, isNotNull);

        // ref.find and findAsync coverage
        Levit.put(() => 'dep', tag: 'd');
        expect(ref.find<String>(tag: 'd'), 'dep');

        return 'ok';
      });

      expect(state.find(), 'ok');
      expect(state.toString(), contains('LevitState'));

      final asyncState = LevitState.async((ref) async {
        await Future.delayed(Duration(milliseconds: 5));
        Levit.lazyPutAsync(() async => 'async_dep', tag: 'ad');
        return await ref.findAsync<String>(tag: 'ad');
      });

      expect(await asyncState.findAsync(), 'async_dep');
      expect(asyncState.toString(), contains('LevitState'));
    });

    test('Levit core find methods coverage', () async {
      final state = LevitState<String>((ref) => 'val');

      // findOrNull
      expect(Levit.findOrNull<String>(key: state), 'val');
      expect(Levit.findOrNull<String>(key: 'invalid'), isNull);

      // findAsync
      expect(await Levit.findAsync<String>(key: state), 'val');

      // findOrNullAsync
      expect(await Levit.findOrNullAsync<String>(key: state), 'val');
      expect(await Levit.findOrNullAsync<String>(key: 'invalid'), isNull);

      // isRegistered and isInstantiated for LevitState
      // Hit lines 172 and 181
      state.find(tag: 'provider_test');
      expect(Levit.isRegistered(key: state, tag: 'provider_test'), true);
      expect(Levit.isInstantiated(key: state, tag: 'provider_test'), true);

      // delete
      expect(Levit.delete(key: state), true);
      expect(Levit.delete(key: state), false); // Already deleted
    });

    test('Auto-linking and adoption coverage', () {
      final state = LevitState<LxVar<int>>((ref) {
        final v = 0.lx;
        return v;
      });

      final v = state.find(tag: 'tag1');
      expect(v.ownerId, contains('tag1'));
    });

    test('LevitRef dispose error log coverage', () {
      final state = LevitState((ref) {
        ref.onDispose(() => throw Exception('onDispose error'));
        return 'test';
      });
      state.find();
      Levit.reset(force: true);
    });

    test('Coverage for private/internal paths', () {
      // runCapturedForTesting is already covered by its own tests or we can add here
    });

    test('LevitStateExtension coverage', () async {
      final state = LevitState((ref) => 'test');
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
