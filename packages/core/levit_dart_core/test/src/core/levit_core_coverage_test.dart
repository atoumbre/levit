import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class UnifiedCaptureMiddleware implements LevitScopeMiddleware {
  dynamic lastInstance;

  @override
  void Function() onDependencyInit<S>(void Function() onInit, S instance,
      LevitScope scope, String key, LevitDependency info) {
    lastInstance = instance;
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
  group('Levit Core and Auto-Linking Coverage', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Levit.reset(force: true);
    });

    test('Levit Core methods fallback coverage', () async {
      final state = LevitState((ref) => 'ok');

      // findOrNull success/fail
      expect(Levit.findOrNull<String>(key: state), 'ok');
      final throwingState =
          LevitState<String>((ref) => throw Exception('error'));
      expect(Levit.findOrNull<String>(key: throwingState), isNull);

      // findAsync success
      final asyncState = LevitState.async((ref) async => 'async');
      expect(await Levit.findAsync<String>(key: asyncState), 'async');

      // findOrNullAsync success
      expect(await Levit.findOrNullAsync<String>(key: asyncState), 'async');

      final unregisteredAsync =
          LevitState.async((ref) async => throw Exception('error'));
      expect(
          await Levit.findOrNullAsync<String>(key: unregisteredAsync), isNull);

      // isRegistered/isInstantiated (Lines 172, 181)
      final provider = LevitState((ref) => 'p');
      expect(Levit.isRegistered(key: provider), false);
      provider.find();
      expect(Levit.isRegistered(key: provider), true);
      expect(Levit.isInstantiated(key: provider), true);
    });

    test('LevitStateInstance internal coverage', () async {
      final middleware = UnifiedCaptureMiddleware();
      Levit.addDependencyMiddleware(middleware);

      final state = LevitState((ref) {
        final v = ref.autoDispose(0.lx);
        return v;
      });
      state.find();

      final dynamic instance = middleware.lastInstance;
      expect(instance, isNotNull);

      // wrappedValue (Line 244)
      expect(await instance.wrappedValue, isA<LxVar<int>>());

      // didAttachToScope adoption loop (Lines 279-290)
      instance.didAttachToScope(LevitScope.root(), key: 'new-key');

      Levit.removeDependencyMiddleware(middleware);
    });

    test('Auto-linking coverage gaps', () {
      Levit.enableAutoLinking();

      // runCaptured without ownerId (auto_linking.dart line 60)
      runCapturedForTesting(() => 1);

      // Chained capture and Adoption in processInstance (auto_linking.dart 184-185)
      Levit.put(() {
        1.lx;
        2.lx;
        return 'test';
      }, tag: 'multi');

      Levit.disableAutoLinking();
    });
  });
}
