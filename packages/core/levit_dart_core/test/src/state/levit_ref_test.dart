import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class InstanceCaptureMiddleware implements LevitScopeMiddleware {
  dynamic lastInstance;

  @override
  void Function() onDependencyInit<S>(void Function() onInit, S instance,
      LevitScope scope, String key, LevitDependency info) {
    if (key.contains('ls_value_')) {
      lastInstance = instance;
    }
    return onInit;
  }

  @override
  void onDependencyDelete(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  void onDependencyRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  void onDependencyResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  S Function() onDependencyCreate<S>(S Function() builder, LevitScope scope,
          String key, LevitDependency info) =>
      builder;
  @override
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {}
  @override
  void onScopeDispose(int scopeId, String scopeName) {}
}

void main() {
  final middleware = InstanceCaptureMiddleware();

  setUp(() {
    Levit.addDependencyMiddleware(middleware);
  });

  tearDown(() {
    Levit.removeDependencyMiddleware(middleware);
    Levit.reset(force: true);
  });

  group('LevitRef Coverage', () {
    test('scope accessor', () {
      final state = LevitStore((ref) {
        expect(ref.scope, isNotNull);
        return 'ok';
      });
      state.find();
    });

    test('find and findAsync fallbacks', () async {
      final state = LevitStore((ref) async {
        Levit.put(() => 'dep', tag: 't');
        expect(ref.find<String>(tag: 't'), 'dep');

        Levit.lazyPutAsync(() async => 'async_dep', tag: 'at');
        final val = await ref.findAsync<String>(tag: 'at');
        expect(val, 'async_dep');

        return 'ok';
      });
      await state.find();
    });

    test('findStoreAsync delegates to store lookup in same scope', () async {
      final base = LevitStore((_) => 123);

      final outer = LevitStore<Future<int>>((ref) {
        return ref.findStoreAsync<int>(base);
      });

      final future = outer.find();
      expect(future, isA<Future<int>>());
      expect(await future, 123);
    });

    test('onDispose error logging', () {
      final state = LevitStore((ref) {
        ref.onDispose(() => throw Exception('dispose error'));
        return 'ok';
      });
      state.find();
      Levit.reset(force: true);
    });

    test('LxReactive fluent API: register, sensitive, named', () {
      final r = 0.lx.named('my_lx').register('owner_1').sensitive();
      expect(r.name, 'my_lx');
      expect(r.ownerId, 'owner_1');
      expect(r.isSensitive, true);
    });

    test('_levitDisposeItem handles LevitScopeDisposable', () {
      final mock = _MockScopeDisposable();
      // Test via Levit.delete
      Levit.put(() => mock);
      expect(mock.closed, false);
      Levit.delete<_MockScopeDisposable>(force: true);
      expect(mock.closed, true);

      // Directly test via autoDispose to hit L280 specifically via _levitDisposeItem
      final mock2 = _MockScopeDisposable();
      final store = LevitStore((ref) {
        ref.autoDispose(mock2);
        return 'ok';
      });
      store.find();
      expect(mock2.closed, false);
      store.delete(force: true);
      expect(mock2.closed, true);
    });
  });
}

class _MockScopeDisposable implements LevitScopeDisposable {
  bool closed = false;
  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
  @override
  void onClose() => closed = true;
  @override
  void onInit() {}
}
