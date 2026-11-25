import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _OwnerController extends LevitController {}

void main() {
  test(
    'own rejects unsupported resource without exposing its raw value in error text',
    () async {
      final scope = LevitScope.root('opaque_own');
      final controller = scope.put(_OwnerController.new);

      expect(
        () => controller.own('super-secret-api-key'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('String'), isNot(contains('super-secret-api-key'))),
          ),
        ),
      );
      await scope.dispose();
    },
  );

  test(
    'LevitStore integer variant tag does not leak raw integer in registration key',
    () async {
      final scope = LevitScope.root('opaque_store_variant');
      final store = LevitStore<int>((_) => 1);
      store.findIn(scope, tag: 42424242);

      final keys = scope.registeredKeys.join(',');
      expect(keys, isNot(contains('42424242')));
      await scope.dispose();
    },
  );
}
