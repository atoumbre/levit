import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _LifecycleLoopController extends LevitController
    with LevitLoopExecutionMixin, LevitLoopExecutionLifecycleMixin {}

class _CountingService implements StoppableService {
  final _status = LxVar<LxStatus<dynamic>>(LxIdle());
  int pauseCount = 0;
  int resumeCount = 0;

  @override
  LxReactive<LxStatus<dynamic>> get status => _status;

  @override
  void pause() {
    pauseCount++;
    _status.value = LxWaiting();
  }

  @override
  void resume() {
    resumeCount++;
    _status.value = LxWaiting();
  }

  @override
  void start() {
    _status.value = LxWaiting();
  }

  @override
  void stop() {
    _status.value = LxIdle();
  }
}

void main() {
  testWidgets(
      'LevitLoopExecutionLifecycleMixin pauses on inactive/hidden/detached',
      (tester) async {
    final controller = _LifecycleLoopController();
    controller.onInit();

    final service = _CountingService();
    controller.loopEngine.registerService('service', service);
    service.start();

    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(service.pauseCount, 1);

    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(service.pauseCount, 2);

    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(service.pauseCount, 3);

    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.resumeCount, 1);

    controller.onClose();
  });
}
