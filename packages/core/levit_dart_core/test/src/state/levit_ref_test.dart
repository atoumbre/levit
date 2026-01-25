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
      final state = LevitState((ref) {
        expect(ref.scope, isNotNull);
        return 'ok';
      });
      state.find();
    });

    test('find and findAsync fallbacks', () async {
      final state = LevitState((ref) async {
        Levit.put(() => 'dep', tag: 't');
        expect(ref.find<String>(tag: 't'), 'dep');

        Levit.lazyPutAsync(() async => 'async_dep', tag: 'at');
        final val = await ref.findAsync<String>(tag: 'at');
        expect(val, 'async_dep');

        return 'ok';
      });
      await state.find();
    });

    test('onDispose error logging', () {
      final state = LevitState((ref) {
        ref.onDispose(() => throw Exception('dispose error'));
        return 'ok';
      });
      state.find();
      Levit.reset(force: true);
    });
  });

  group('LevitStateInstance Coverage', () {
    test('wrappedValue for sync state', () async {
      final state = LevitState((ref) => 'sync');
      state.find(tag: 'sync_t');

      final dynamic instance = middleware.lastInstance;
      expect(instance, isNotNull);
      expect(await instance.wrappedValue, 'sync');
    });

    test('wrappedValue for async state', () async {
      final state = LevitState.async((ref) async => 'async');
      await state.findAsync(tag: 'async_t');

      final dynamic instance = middleware.lastInstance;
      expect(instance, isNotNull);
      expect(await instance.wrappedValue, 'async');
    });
  });
}
