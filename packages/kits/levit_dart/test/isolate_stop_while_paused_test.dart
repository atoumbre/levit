import 'dart:async';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void _noopLoopBody() {}
void _fastLoopBody() {}

class TestLoopController extends LevitController with LevitLoopExecutionMixin {}

void main() {
  group('LevitLoopExecutionMixin Isolate Coverage', () {
    test('pause requested immediately keeps isolate loop waiting', () async {
      final controller = TestLoopController();
      controller.onInit();

      controller.loopEngine.startIsolateLoop(
        'paused_before_ready',
        _fastLoopBody,
        delay: const Duration(milliseconds: 10),
      );
      controller.loopEngine.pauseService('paused_before_ready');

      await Future.delayed(const Duration(milliseconds: 150));

      expect(
        controller.loopEngine.getServiceStatus('paused_before_ready')?.value,
        isA<LxWaiting<dynamic>>(),
      );

      controller.loopEngine.stopService('paused_before_ready');
      controller.onClose();
    });

    test('stop an isolate loop while it is paused', () async {
      final controller = TestLoopController();
      controller.onInit();

      // Start an isolate loop
      controller.loopEngine.startIsolateLoop('test_loop', _noopLoopBody,
          delay: const Duration(milliseconds: 10));

      // Wait for it to start
      await Future.delayed(const Duration(milliseconds: 50));

      // Pause it
      controller.loopEngine.pauseService('test_loop');
      await Future.delayed(const Duration(milliseconds: 20));

      // Stop it while paused (This should hit the cleanup path for pauseCompleter in isolate)
      controller.loopEngine.stopService('test_loop');

      expect(controller.loopEngine.getServiceStatus('test_loop'), isNull);

      controller.onClose();
    });
  });
}
