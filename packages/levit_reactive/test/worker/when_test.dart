import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('watchTrue/watchFalse/watchValue', () {
    test('watchTrue fires when bool becomes true', () async {
      final flag = false.lx;
      var fired = false;

      LxWatch.isTrue(flag, () => fired = true);

      flag.setTrue();
      await Future.microtask(() {});
      expect(fired, true);
    });

    test('watchTrue does not fire when bool becomes false', () async {
      final flag = true.lx;
      var fired = false;

      LxWatch.isTrue(flag, () => fired = true);

      flag.setFalse();
      await Future.microtask(() {});
      expect(fired, false);
    });

    test('watchFalse fires when bool becomes false', () async {
      final flag = true.lx;
      var fired = false;

      LxWatch.isFalse(flag, () => fired = true);

      flag.setFalse();
      await Future.microtask(() {});
      expect(fired, true);
    });

    test('watchFalse does not fire when bool becomes true', () async {
      final flag = false.lx;
      var fired = false;

      LxWatch.isFalse(flag, () => fired = true);

      flag.setTrue();
      await Future.microtask(() {});
      expect(fired, false);
    });

    test('watchValue fires when value matches target', () async {
      final status = 'idle'.lx;
      var fired = false;

      LxWatch.isValue(status, 'complete', () => fired = true);

      status.value = 'loading';
      await Future.microtask(() {});
      expect(fired, false);

      status.value = 'complete';
      await Future.microtask(() {});
      expect(fired, true);
    });

    test('dispose cancels subscription', () async {
      final flag = false.lx;
      var fireCount = 0;

      final dispose = LxWatch.isTrue(flag, () => fireCount++);

      flag.setTrue();
      await Future.microtask(() {});
      expect(fireCount, 1);

      dispose.close();

      flag.setFalse();
      flag.setTrue();
      await Future.microtask(() {});
      expect(fireCount, 1); // Not fired after dispose
    });
  });
}
