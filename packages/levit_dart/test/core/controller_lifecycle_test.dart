import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController {}

void main() {
  setUp(() => Levit.reset(force: true));
  tearDown(() => Levit.reset(force: true));

  group('LevitController Scope Access', () {
    test('scope property is null initially', () {
      final controller = TestController();
      expect(controller.scope, isNull);
    });

    test('scope is set after resolution via DI', () {
      final scope = Levit.createScope('test_scope');
      scope.put(() => TestController());

      final controller = scope.find<TestController>();

      expect(controller.scope, equals(scope));
      expect(controller.scope!.name, contains('test_scope'));
    });

    test('manual didAttachToScope sets scope', () {
      final controller = TestController();
      final scope = Levit.createScope('manual');

      controller.didAttachToScope(scope);

      expect(controller.scope, equals(scope));
    });
  });
}
