import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  test('LevitController updates ownerId for non-LxBase LxReactive items', () {
    final controller = TestController();
    // Simulate manual construction without scope

    // Create a reactive that is strictly LxReactive but NOT LxBase
    // Note: implementing LxReactive directly
    final customReactive = CustomReactive();
    expect(customReactive.ownerId, isNull);

    controller.addCustomReactive(customReactive);

    // Manually trigger didAttachToScope as Levit.put would
    // We can use a mock scope or a real one. Real one is easier.
    final scope = LevitScope.root();
    controller.didAttachToScope(scope, key: 'custom_ctrl');

    // Verification:
    // The controller should have updated the ownerId of customReactive
    // matching the logic at controller.dart:86-87
    expect(customReactive.ownerId, '${scope.id}:custom_ctrl');
  });

  test('didAttachToScope swallows reactive refresh failures', () {
    final controller = TestController();
    final reactive = ThrowingReactive(throwOnRefresh: true);
    controller.addCustomReactive(reactive);

    final scope = LevitScope.root();
    expect(
      () => controller.didAttachToScope(scope, key: 'refresh_fail'),
      returnsNormally,
    );
    expect(reactive.ownerId, '${scope.id}:refresh_fail');
  });

  test('onClose swallows disposal failures from reactive close', () {
    final controller = TestController();
    controller.addCustomReactive(ThrowingReactive(throwOnClose: true));

    expect(() => controller.onClose(), returnsNormally);
    expect(controller.isClosed, isTrue);
  });
}

class TestController extends LevitController {
  void addCustomReactive(LxReactive rx) {
    autoDispose(rx);
  }
}

class CustomReactive implements LxReactive<int> {
  @override
  String? ownerId;

  @override
  String? name;

  @override
  int get value => 0;

  set value(int v) {}

  @override
  void close() {}

  @override
  void refresh() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ThrowingReactive implements LxReactive<int> {
  ThrowingReactive({this.throwOnRefresh = false, this.throwOnClose = false});

  final bool throwOnRefresh;
  final bool throwOnClose;

  @override
  String? ownerId;

  @override
  String? name;

  @override
  int get value => 0;

  @override
  set value(int _) {}

  @override
  void close() {
    if (throwOnClose) {
      throw StateError('close fail');
    }
  }

  @override
  void refresh() {
    if (throwOnRefresh) {
      throw StateError('refresh fail');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
