import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestTimeController extends LevitController with LevitTimeMixin {}

void main() {
  group('LevitTimeMixin', () {
    test('Debounce logic works', () async {
      final controller = TestTimeController();
      controller.onInit();
      int callCount = 0;

      // Call repeatedly
      controller.debounce(
          'test', const Duration(milliseconds: 50), () => callCount++);
      controller.debounce(
          'test', const Duration(milliseconds: 50), () => callCount++);
      controller.debounce(
          'test', const Duration(milliseconds: 50), () => callCount++);

      // Should not have run yet
      expect(callCount, 0);

      // Wait
      await Future.delayed(const Duration(milliseconds: 100));
      expect(callCount, 1);

      controller.onClose();
    });

    test('Throttle logic works', () async {
      final controller = TestTimeController();
      controller.onInit();
      int callCount = 0;

      // First call runs immediately
      controller.throttle(
          'test', const Duration(milliseconds: 100), () => callCount++);
      expect(callCount, 1);

      // Subsequent calls ignored
      controller.throttle(
          'test', const Duration(milliseconds: 100), () => callCount++);
      expect(callCount, 1);

      // Wait for cool down
      await Future.delayed(const Duration(milliseconds: 150));

      // Can run again
      controller.throttle(
          'test', const Duration(milliseconds: 100), () => callCount++);
      expect(callCount, 2);

      controller.onClose();
    });

    test('Countdown logic works', () async {
      final controller = TestTimeController();
      controller.onInit();

      final countdown = controller.startCountdown(
        duration: const Duration(seconds: 3),
        interval: const Duration(milliseconds: 100), // Fast ticks for test
      );

      expect(countdown.remaining.value.inSeconds, 3);

      // Simulate a tick (wait slightly more than interval)
      await Future.delayed(const Duration(milliseconds: 150));
      expect(countdown.remaining.value < const Duration(seconds: 3), isTrue);

      controller.onClose();
    });
  });
}
