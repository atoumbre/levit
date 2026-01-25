import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

class PeriodicController extends LevitController with LevitTimeMixin {}

class DebounceController extends LevitController with LevitTimeMixin {}

void main() {
  group('LevitTimeMixin (Interval)', () {
    test('startInterval runs callback repeatedly', () async {
      final controller = PeriodicController();
      controller.onInit();
      int count = 0;

      // New API requires ID
      controller.startInterval(
          'test_interval', const Duration(milliseconds: 10), (timer) {
        count++;
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, greaterThanOrEqualTo(3));

      controller.onClose();
    });

    test('onClose cancels interval', () async {
      final controller = PeriodicController();
      controller.onInit();
      int count = 0;

      controller.startInterval(
          'test_interval', const Duration(milliseconds: 10), (timer) {
        count++;
      });

      await Future.delayed(const Duration(milliseconds: 20));
      final countBefore = count;

      controller.onClose();

      await Future.delayed(const Duration(milliseconds: 50));
      // Should not increment significantly after close (timing can be tricky but shouldn't run indefinitely)
      expect(count, countBefore);
    });
  });

  group('LevitTimeMixin (Debounce)', () {
    test('debounce limits execution', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      void trigger() =>
          controller.debounce('id', const Duration(milliseconds: 20), () {
            runs++;
          });

      trigger();
      trigger();
      trigger();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(runs, 1);

      controller.onClose();
    });

    test('cancelTimer prevents execution', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      controller.debounce('id', const Duration(milliseconds: 20), () {
        runs++;
      });

      // Renamed API
      controller.cancelTimer('id');

      await Future.delayed(const Duration(milliseconds: 50));
      expect(runs, 0);

      controller.onClose();
    });

    test('onClose cancels pending debounce', () async {
      final controller = DebounceController();
      controller.onInit();
      int runs = 0;

      controller.debounce('id', const Duration(milliseconds: 50), () {
        runs++;
      });

      controller.onClose();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(runs, 0);
    });
  });
}
