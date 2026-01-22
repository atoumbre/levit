import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController {}

class ThrowingDisposable {
  void dispose() => throw Exception('Dispose failed');
}

class ThrowingCancelable {
  void cancel() => throw Exception('Cancel failed');
}

class ThrowingCloseable {
  void close() => throw Exception('Close failed');
}

void main() {
  group('LevitController Disposal Edge Cases', () {
    test('autoDispose handles Timer and Sink', () {
      final controller = TestController();
      final timer = Timer(const Duration(hours: 1), () {});
      controller.autoDispose(timer);

      final sc = StreamController<int>();
      controller.autoDispose(sc.sink);

      controller.onClose();
      expect(timer.isActive, false);
      expect(sc.isClosed, true);
    });

    test('autoDispose handles exceptions during cleanup', () {
      final controller = TestController();

      controller.autoDispose(ThrowingDisposable());
      controller.autoDispose(ThrowingCancelable());
      controller.autoDispose(ThrowingCloseable());

      // Should not throw as it is caught in LevitController._disposeItem
      expect(() => controller.onClose(), returnsNormally);
    });

    test('identical objects are not added twice', () {
      final controller = TestController();
      final timer = Timer(Duration.zero, () {});
      controller.autoDispose(timer);
      controller.autoDispose(timer);
      controller.onClose();
    });
  });
}
