import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class MyMiddleware implements LevitReactiveMiddleware, LevitScopeMiddleware {
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
  test('Non-controller onInit capture', () {
    final instance = NonControllerDisposable();
    Levit.put(() => instance);
    expect(instance.count.ownerId, isNull);
  });
}
