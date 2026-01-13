import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LevitController (Pure Dart)', () {
    test('lifecycle hooks are called', () {
      final controller = TestController();

      expect(controller.initialized, isFalse);
      controller.onInit();
      expect(controller.initialized, isTrue);

      expect(controller.closeCalled, isFalse);
      controller.onClose();
      expect(controller.closeCalled, isTrue);
    });

    test('isClosed is alias for isDisposed', () {
      final controller = TestController();

      expect(controller.isDisposed, isFalse);

      controller.onClose();

      expect(controller.isDisposed, isTrue);
    });

    test('initialized getter works', () {
      final ctrl = TestController();
      expect(ctrl.initialized, isFalse);
      ctrl.onInit();
      expect(ctrl.initialized, isTrue);
    });
  });

  group('LevitController autoDispose', () {
    test('disposes StreamSubscription on close', () async {
      final controller = TestController();

      final stream = Stream.value(1).listen((_) {});
      final sub = TrackingSubscription(stream);
      controller.autoDispose(sub);

      controller.onClose();

      expect(sub.cancelCalled, isTrue);
    });

    test('disposes watch closure on close', () {
      final controller = TestController();
      final count = 0.lx;
      bool disposed = false;

      final disposeFunc = LxWatch(count, (_) {});
      controller.autoDispose(() {
        disposeFunc();
        disposed = true;
      });

      expect(disposed, isFalse);

      controller.onClose();

      expect(disposed, isTrue);
    });

    test('disposes LxFuture on close', () async {
      final controller = TestController();
      final future = LxFuture<int>(Future.value(42));

      controller.autoDispose(future);

      await Future.delayed(Duration.zero);

      controller.onClose();

      expect(() => future.close(), returnsNormally);
    });

    test('calls Function on close', () {
      final controller = TestController();
      bool functionCalled = false;

      controller.autoDispose(() => functionCalled = true);

      controller.onClose();

      expect(functionCalled, isTrue);
    });

    test('prevents double close', () {
      final controller = TestController();
      int closeCount = 0;

      controller.autoDispose(() => closeCount++);

      controller.onClose();
      controller.onClose();

      expect(closeCount, 1);
    });

    test('onClose sets isDisposed', () {
      final controller = TestController();

      expect(controller.isDisposed, isFalse);

      controller.onClose();

      expect(controller.isDisposed, isTrue);
      expect(controller.closeCalled, isTrue);
    });

    test('disposes LxStream on close', () async {
      final controller = TestController();
      final streamController = StreamController<int>.broadcast();
      final stream = LxStream(streamController.stream);

      controller.autoDispose(stream);

      controller.onClose();

      expect(() => stream.close(), returnsNormally);
      streamController.close();
    });

    test('disposes LxComputed on close', () async {
      final controller = TestController();
      final count = 0.lx;
      final computed = LxComputed(() => count.value * 2);

      controller.autoDispose(computed);

      controller.onClose();

      await Future.delayed(Duration.zero);
      expect(() => computed.close(), returnsNormally);
    });
  });
}
