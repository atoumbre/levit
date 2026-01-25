import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class GenericDisposable extends LevitScopeDisposable {
  late final count = 0.lx;

  @override
  void onInit() {
    // Accessing late final in onInit sets its ownerId
    print('Count ownerId in onInit: ${count.ownerId}');
    final inner = 1.lx;
    print('Inner ownerId: ${inner.ownerId}');
  }
}

void main() {
  test('Auto-linking ownerId registration for generic LevitScopeDisposable',
      () {
    Levit.enableAutoLinking();
    final scope = LevitScope.root();

    final instance = scope.put(() => GenericDisposable());

    expect(instance.count.ownerId, isNotNull);
    expect(instance.count.ownerId, contains('GenericDisposable'));
  });
}
