import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _GuardedController extends LevitController {}

void main() {
  group('LevitController.runGuardedAsync', () {
    test('returns result while controller is open', () async {
      final controller = _GuardedController();

      final result = await controller.runGuardedAsync(() async => 42);

      expect(result, 42);
    });

    test('returns null when already closed and cancelOnClose=true', () async {
      final controller = _GuardedController();
      controller.onClose();

      final result = await controller.runGuardedAsync(() async => 42);

      expect(result, isNull);
    });

    test('returns result when already closed and cancelOnClose=false',
        () async {
      final controller = _GuardedController();
      controller.onClose();

      final result = await controller.runGuardedAsync(
        () async => 42,
        cancelOnClose: false,
      );

      expect(result, 42);
    });

    test('returns null if controller closes before action completes', () async {
      final controller = _GuardedController();
      final completer = Completer<int>();

      final future = controller.runGuardedAsync(() async {
        return completer.future;
      });

      controller.onClose();
      completer.complete(7);

      expect(await future, isNull);
    });

    test('reports error and rethrows', () async {
      final controller = _GuardedController();
      Object? receivedError;

      final future = controller.runGuardedAsync<void>(
        () async => throw StateError('boom'),
        onError: (error, _) => receivedError = error,
      );

      await expectLater(future, throwsA(isA<StateError>()));
      expect(receivedError, isA<StateError>());
    });
  });
}
