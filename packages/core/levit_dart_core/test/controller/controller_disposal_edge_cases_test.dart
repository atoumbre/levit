import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
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
    test('own handles Timer and Sink', () async {
      final controller = TestController();
      final timer = Timer(const Duration(hours: 1), () {});
      controller.own(timer);

      final sc = StreamController<int>.broadcast();
      controller.own(sc.sink);

      await controller.onClose();
      expect(timer.isActive, false);
      expect(sc.isClosed, true);
    });

    test('own handles StreamSubscription', () async {
      final controller = TestController();
      var cancelCalled = false;
      final streamController = StreamController<int>.broadcast(
        onCancel: () {
          cancelCalled = true;
        },
      );
      final subscription = streamController.stream.listen((_) {});
      controller.own(subscription);

      await controller.onClose();
      await Future<void>.delayed(Duration.zero);

      expect(cancelCalled, isTrue);
      await streamController.close();
    });

    test('own aggregates exceptions after cleanup', () async {
      final controller = TestController();

      controller.own(ThrowingDisposable(), dispose: (value) => value.dispose());
      controller.own(ThrowingCancelable(), dispose: (value) => value.cancel());
      controller.own(ThrowingCloseable(), dispose: (value) => value.close());

      await expectLater(
        controller.onClose(),
        throwsA(
          isA<LevitDisposalException>().having(
            (error) => error.failures.length,
            'failure count',
            3,
          ),
        ),
      );
      expect(controller.isClosed, isTrue);
    });

    test('identical objects are not added twice', () async {
      final controller = TestController();
      final timer = Timer(Duration.zero, () {});
      controller.own(timer);
      controller.own(timer);
      await controller.onClose();
    });
  });
}
