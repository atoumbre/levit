import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../helpers.dart';
import 'package:levit_reactive/spi.dart';

void main() {
  group('LxProxy', () {
    test('observer receives streams when value is read', () {
      final count = 0.lx;
      final observer = MockObserver();

      LxSpi.proxy = observer;
      final _ = count.value; // Read triggers registration
      LxSpi.proxy = null;

      expect(observer.notifiers, hasLength(1));
    });

    test('observer only receives streams during active proxy', () {
      final count = 0.lx;
      final name = ''.lx;
      final observer = MockObserver();

      // Read without proxy
      final _ = count.value;
      expect(observer.notifiers, isEmpty);

      // Read with proxy
      LxSpi.proxy = observer;
      // ignore: unused_local_variable
      final val1 = count.value;
      // ignore: unused_local_variable
      final val2 = name.value;
      LxSpi.proxy = null;

      expect(observer.notifiers, hasLength(2));
    });
  });
}
