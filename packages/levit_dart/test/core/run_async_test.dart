import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope.runAsync', () {
    test('executes callback in scope zone', () async {
      final scope = Levit.createScope('test_async_scope');

      scope.put<int>(() => 42);

      await scope.run(() async {
        expect(Levit.find<int>(), equals(42));
      });
    });

    test('returns future value', () async {
      final scope = Levit.createScope('test_async_return');

      scope.put<int>(() => 42);

      final result = await scope.run(() async {
        await Future.delayed(Duration.zero);

        return 'success: ${Levit.find<int>()}';
      });

      expect(result, equals('success: 42'));
    });
  });
}
