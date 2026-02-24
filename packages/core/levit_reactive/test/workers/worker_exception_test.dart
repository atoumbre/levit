import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxWorker async exception handling', () {
    test('debounce catches async exceptions and routes to onProcessingError',
        () async {
      final source = 0.lx;
      Object? caughtError;

      LxWorker.debounce(
        source,
        const Duration(milliseconds: 10),
        (value) {
          throw Exception('Debounce async error');
        },
        onProcessingError: (e, st) {
          caughtError = e;
        },
      );

      source.value = 1;

      // Wait for debounce timer + execution
      await Future.delayed(const Duration(milliseconds: 50));

      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('Debounce async error'));
    });

    test('throttle catches async exceptions and routes to onProcessingError',
        () async {
      final source = 0.lx;
      Object? caughtError;

      LxWorker.throttle(
        source,
        const Duration(milliseconds: 10),
        (value) {
          throw Exception('Throttle async error');
        },
        onProcessingError: (e, st) {
          caughtError = e;
        },
      );

      source.value = 1;

      // Throttle executes immediately
      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('Throttle async error'));
    });

    test(
        'debounce catches async exceptions and routes to global handler if no onProcessingError',
        () async {
      final source = 0.lx;
      Object? caughtError;

      runZonedGuarded(() {
        LxWorker.debounce(
          source,
          const Duration(milliseconds: 10),
          (value) {
            throw Exception('Debounce async global error');
          },
        );
        source.value = 1;
      }, (e, st) {
        caughtError = e;
      });

      // Wait for debounce timer + execution
      await Future.delayed(const Duration(milliseconds: 50));

      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('Debounce async global error'));
    });

    test(
        'throttle catches async exceptions and routes to global handler if no onProcessingError',
        () async {
      final source = 0.lx;
      Object? caughtError;

      runZonedGuarded(() {
        LxWorker.throttle(
          source,
          const Duration(milliseconds: 10),
          (value) {
            throw Exception('Throttle async global error');
          },
        );
        source.value = 2; // Trigger throttle
      }, (e, st) {
        caughtError = e;
      });

      // Wait a bit to ensure it runs
      await Future.delayed(const Duration(milliseconds: 10));

      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('Throttle async global error'));
    });
  });
}
