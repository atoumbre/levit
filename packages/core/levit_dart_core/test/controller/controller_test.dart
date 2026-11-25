import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  setUp(() async {
    await Levit.reset(force: true);
  });

  group('LevitController (Pure Dart)', () {
    test('lifecycle hooks are called', () async {
      final controller = TestController();

      expect(controller.isInitialized, isFalse);
      controller.onInit();
      expect(controller.isInitialized, isTrue);

      expect(controller.closeCalled, isFalse);
      await controller.onClose();
      expect(controller.closeCalled, isTrue);
    });

    test('isClosed is alias for isDisposed', () async {
      final controller = TestController();

      expect(controller.isDisposed, isFalse);

      await controller.onClose();

      expect(controller.isDisposed, isTrue);
    });

    test('initialized getter works', () {
      final ctrl = TestController();
      expect(ctrl.isInitialized, isFalse);
      ctrl.onInit();
      expect(ctrl.isInitialized, isTrue);
    });
  });

  group('LevitController own', () {
    test('disposes StreamSubscription on close', () async {
      final controller = TestController();

      final stream = Stream.value(1).listen((_) {});
      final sub = TrackingSubscription(stream);
      controller.own(sub);

      await controller.onClose();

      expect(sub.cancelCalled, isTrue);
    });

    test('disposes watch closure on close', () async {
      final controller = TestController();
      final count = 0.lx;
      bool disposed = false;

      final disposeFunc = LxWorker(count, (_) {});
      controller.own(() {
        disposeFunc();
        disposed = true;
      });

      expect(disposed, isFalse);

      await controller.onClose();

      expect(disposed, isTrue);
    });

    test('disposes LxFuture on close', () async {
      final controller = TestController();
      final future = LxFuture<int>(Future.value(42));

      controller.own(future);

      await Future.delayed(Duration.zero);

      await controller.onClose();

      expect(() => future.close(), returnsNormally);
    });

    test('calls Function on close', () async {
      final controller = TestController();
      bool functionCalled = false;

      controller.own(() => functionCalled = true);

      await controller.onClose();

      expect(functionCalled, isTrue);
    });

    test('prevents double close', () async {
      final controller = TestController();
      int closeCount = 0;

      controller.own(() => closeCount++);

      await controller.onClose();
      await controller.onClose();

      expect(closeCount, 1);
    });

    test('onClose sets isDisposed', () async {
      final controller = TestController();

      expect(controller.isDisposed, isFalse);

      await controller.onClose();

      expect(controller.isDisposed, isTrue);
      expect(controller.closeCalled, isTrue);
    });

    test('disposes LxStream on close', () async {
      final controller = TestController();
      final streamController = StreamController<int>.broadcast();
      final stream = LxStream(streamController.stream);

      controller.own(stream);

      await controller.onClose();

      expect(() => stream.close(), returnsNormally);
      streamController.close();
    });

    test('disposes LxComputed on close', () async {
      final controller = TestController();
      final count = 0.lx;
      final computed = LxComputed(() => count.value * 2);

      controller.own(computed);

      await controller.onClose();

      await Future.delayed(Duration.zero);
      expect(() => computed.close(), returnsNormally);
    });
  });
}
