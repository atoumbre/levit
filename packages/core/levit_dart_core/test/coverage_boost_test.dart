import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class MyMiddleware implements LevitReactiveMiddleware, LevitScopeMiddleware {
  // Implement missing methods from LevitReactiveMiddleware
  @override
  LxOnSet? get onSet => null;
  @override
  LxOnBatch? get onBatch => null;
  @override
  LxOnDispose? get onDispose => null;
  @override
  void Function(LxReactive)? get onInit => null;
  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening => null;
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening => null;

  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError => null;

  // Implement missing methods from LevitScopeMiddleware
  @override
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {}
  @override
  void onScopeDispose(int scopeId, String scopeName) {}
  @override
  void onDependencyRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  void onDependencyResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  void onDependencyDelete(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}
  @override
  S Function() onDependencyCreate<S>(S Function() builder, LevitScope scope,
          String key, LevitDependency info) =>
      builder;
  @override
  void Function() onDependencyInit<S>(void Function() onInit, S instance,
          LevitScope scope, String key, LevitDependency info) =>
      onInit;
}

class MyController extends LevitController {
  final count = 0.lx;
}

class NonControllerDisposable extends LevitScopeDisposable {
  final count = 0.lx;
  @override
  void onInit() {
    count.value = 1;
  }
}

class AsyncInitController extends LevitController {
  LxVar<int>? rx;
  @override
  Future<void> onInit() async {
    super.onInit();
    await Future.delayed(Duration(milliseconds: 10));
    rx = 1.lx;
  }
}

class ErrorInitController extends LevitController {
  @override
  void onInit() {
    super.onInit();
    throw Exception('Init error');
  }
}

void main() {
  setUp(() {
    Levit.reset(force: true);
    Lx.clearMiddlewares();
    Levit.enableAutoLinking();
  });

  group('Levit Dart Coverage Boost', () {
    test('LevitMiddleware default methods (middleware.dart)', () {
      final mw = MyMiddleware();

      mw.onDependencyRegister(
          0, 'scope', 'key', LevitDependency(instance: null),
          source: 'src');
      mw.onDependencyResolve(0, 'scope', 'key', LevitDependency(instance: null),
          source: 'src');
      mw.onDependencyDelete(0, 'scope', 'key', LevitDependency(instance: null),
          source: 'src');

      final builder = mw.onDependencyCreate(
          () => 42, LevitScope.root(), 'key', LevitDependency(instance: null));
      expect(builder(), 42);

      final init = mw.onDependencyInit(
          () {}, 42, LevitScope.root(), 'key', LevitDependency(instance: null));
      init();
    });

    test('Async Capture Hook coverage', () async {
      final future = Levit.put(() async {
        return MyController();
      });
      await future;
    });

    test('Capture Hook Error path', () {
      // Must have some middleware to trigger the slow path/capture scopes
      Levit.enableAutoLinking();
      expect(() => Levit.put(() => throw Exception('Builder error')),
          throwsException);
    });

    test('Non-controller onInit capture', () {
      final instance = NonControllerDisposable();
      Levit.put(() => instance);
      // Non-controllers are not automatically linked yet (expected behavior)
      expect(instance.count.ownerId, isNull);
    });

    test('Async onInit capture', () async {
      final controller = Levit.put(() => AsyncInitController());
      // Wait for async init
      await Future.delayed(Duration(milliseconds: 50));
      expect(controller.rx, isNotNull);
    });

    test('Capture Hook onInit error path', () {
      expect(() => Levit.put(() => ErrorInitController()), throwsException);
    });

    test('Fast Path with Controller', () {
      // Clear all middlewares to ensure we hit the fast path
      Lx.clearMiddlewares();
      final controller = Levit.put(() => MyController());
      // No ownerId because no auto-linking middleware was active
      expect(controller.count.ownerId, isNull);
      Levit.enableAutoLinking();
    });
  });
}
