import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

void _noopBody() {}

class _LoopController extends LevitController with LevitLoopExecutionMixin {}

void main() {
  test('isolate loop start/stop can race without leaving stale service state',
      () async {
    final controller = _LoopController();
    controller.onInit();

    controller.loopEngine.startIsolateLoop(
      'iso',
      _noopBody,
      delay: const Duration(milliseconds: 10),
    );
    controller.loopEngine.stopService('iso');

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.loopEngine.getServiceStatus('iso'), isNull);

    controller.loopEngine.startIsolateLoop(
      'iso',
      _noopBody,
      delay: const Duration(milliseconds: 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.loopEngine.getServiceStatus('iso'), isNotNull);

    controller.loopEngine.stopService('iso');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.loopEngine.getServiceStatus('iso'), isNull);

    controller.onClose();
  });
}
