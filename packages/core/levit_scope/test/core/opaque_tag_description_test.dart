import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test(
    'describe emits opaque tag identifiers rather than raw integer tags',
    () async {
      final scope = LevitScope.root('opaque_tags');
      scope.put<String>(() => 'u1', tag: 987654321);
      scope.put<String>(() => 'u2', tag: 'secret-user-tag');

      final description = scope.describe();
      final jsonText = description.toJson().toString();
      expect(jsonText, isNot(contains('987654321')));
      expect(jsonText, isNot(contains('secret-user-tag')));

      final keys = description.registrations.map((r) => r.key).toList();
      expect(keys, ['String#tag1', 'String#tag2']);

      // Repeated describe calls keep stable opaque IDs within the scope.
      expect(scope.describe().registrations.map((r) => r.key).toList(), keys);
      await scope.dispose();
    },
  );
}
