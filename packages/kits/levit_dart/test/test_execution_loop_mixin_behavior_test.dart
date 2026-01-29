import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

// Top-level function for Isolate tests
void _testIsolateLoopBody() {
  // Simple body
}

class TestLoopController extends LevitController with LevitExecutionLoopMixin {}

class MockStoppableService extends StoppableService {
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());
  bool started = false;
  bool paused = false;
  bool stopped = false;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void start() {
    started = true;
    _status.value = LxWaiting();
  }

  @override
  void pause() {
    paused = true;
  }

  @override
  void resume() {
    paused = false;
  }

  @override
  void stop() {
    stopped = true;
    _status.value = LxIdle();
  }
}

void main() {
  group('LevitExecutionLoopMixin', () {
    late TestLoopController controller;

    setUp(() {
      controller = TestLoopController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('startLoop executes body and respects delay', () async {
      int count = 0;
      final completer = Completer<void>();

      controller.startLoop('test_loop', () async {
        count++;
        if (count == 2) {
          completer.complete();
        }
      }, delay: const Duration(milliseconds: 10));

      await completer.future;
      expect(count, greaterThanOrEqualTo(2));
      expect(controller.getServiceStatus('test_loop')?.value, isA<LxSuccess>());
    });

    test('pauseLoop and resumeLoop control execution', () async {
      int count = 0;
      controller.startLoop('pause_test', () async {
        count++;
      }, delay: const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 25));
      final countBeforePause = count;
      expect(countBeforePause, greaterThan(0));

      controller.pauseService('pause_test');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, countBeforePause,
          reason: 'Should not increment while paused');

      controller.resumeService('pause_test');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, greaterThan(countBeforePause),
          reason: 'Should increment after resume');
    });

    test('stopService stops execution and removes from map', () async {
      int count = 0;
      controller.startLoop('stop_test', () async {
        count++;
      }, delay: const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 25));
      expect(count, greaterThan(0));

      controller.stopService('stop_test');
      final countAtStop = count;
      await Future.delayed(const Duration(milliseconds: 50));
      expect(count, countAtStop);
      expect(controller.getServiceStatus('stop_test'), isNull);
    });

    test('registerService manages custom stoppable services', () {
      final mock = MockStoppableService();
      controller.registerService('mock', mock);
      mock.start();

      expect(mock.started, isTrue);
      expect(controller.getServiceStatus('mock')?.value, isA<LxWaiting>());

      controller.pauseService('mock');
      expect(mock.paused, isTrue);

      controller.resumeService('mock');
      expect(mock.paused, isFalse);

      controller.stopService('mock');
      expect(mock.stopped, isTrue);
    });

    test('startIsolateLoop executes in separate isolate', () async {
      // Since we can't easily check 'out-of-isolate' without complex plumbing,
      // we check that it starts and can be stopped.
      controller.startIsolateLoop('isolate_loop', _testIsolateLoopBody,
          delay: const Duration(milliseconds: 10));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(
          controller.getServiceStatus('isolate_loop')?.value, isA<LxSuccess>());

      controller.stopService('isolate_loop');
    });

    test('onClose stops all services', () {
      final mock1 = MockStoppableService();
      final mock2 = MockStoppableService();
      controller.registerService('m1', mock1);
      controller.registerService('m2', mock2);

      controller.onClose();
      expect(mock1.stopped, isTrue);
      expect(mock2.stopped, isTrue);
    });

    test('error in loop body updates status to LxError', () async {
      final completer = Completer<void>();
      controller.startLoop('error_loop', () async {
        if (!completer.isCompleted) completer.complete();
        throw Exception('loop error');
      }, delay: const Duration(milliseconds: 50));

      await completer.future;
      await Future.delayed(const Duration(milliseconds: 10));
      expect(controller.getServiceStatus('error_loop')?.value, isA<LxError>());
      controller.stopService('error_loop'); // Ensure we stop it
    });

    test('registering service with same ID stops previous', () {
      final mock1 = MockStoppableService();
      final mock2 = MockStoppableService();
      controller.registerService('id', mock1);
      controller.registerService('id', mock2);

      expect(mock1.stopped, isTrue);
    });
  });
}
