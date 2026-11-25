import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  test('nullable, Object?, and dynamic calls only read', () {
    final values = <LxVar<dynamic>>[
      LxVar<String?>('kept'),
      LxVar<Object?>('kept'),
      LxVar<dynamic>('kept'),
    ];
    for (final source in values) {
      var notifications = 0;
      source.addListener(() => notifications++);
      final derived = LxComputed(() => source());
      expect(source(), 'kept');
      expect(derived(), 'kept');
      expect(source.value, 'kept');
      expect(notifications, 0);
      source.value = null;
      expect(source(), isNull);
      expect(notifications, 1);
      derived.close();
      source.close();
    }
  });
}
