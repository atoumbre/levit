import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class TestController extends LevitController
    with LevitSelectionMixin<int>, LevitExecutionLoopMixin, LevitTimeMixin {
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();
  }
}

void main() {
  group('levit_dart Final Gaps', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('LevitSelectionMixin gaps', () {
      controller.toggle(1);
      expect(controller.isSelected(1), isTrue);
      controller.toggle(1);
      expect(controller.isSelected(1), isFalse);
    });

    test('LevitTimeMixin gaps', () async {
      final countdown = controller.startCountdown(
        duration: Duration(milliseconds: 100),
        interval: Duration(milliseconds: 10),
      );

      countdown.pause();
      final valAtPause = countdown.remaining.value;
      await Future.delayed(Duration(milliseconds: 30));
      expect(countdown.remaining.value, valAtPause);

      countdown.resume();
      await Future.delayed(Duration(milliseconds: 250));
      expect(countdown.remaining.value, Duration.zero);

      countdown.stop();
    });

    test('LevitExecutionLoopMixin gaps', () async {
      int callCount = 0;
      controller.startLoop('perm', () async {
        callCount++;
      }, delay: Duration(milliseconds: 10), permanent: true);

      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount, greaterThan(0));

      controller.pauseAllServices();
      final countAtPauseInternal = callCount;
      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount,
          greaterThan(countAtPauseInternal)); // Should NOT pause 'perm'

      controller.pauseAllServices(force: true);
      final countAtPauseForced = callCount;
      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount, countAtPauseForced); // Should pause 'perm'

      controller.resumeAllServices(force: true);
      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount, greaterThan(countAtPauseForced));

      controller.stopService('perm');
    });

    test('LevitExecutionLoopMixin non-permanent gaps', () async {
      int callCount = 0;
      controller.startLoop('non-perm', () async {
        callCount++;
      }, delay: Duration(milliseconds: 10), permanent: false);

      await Future.delayed(Duration(milliseconds: 30));
      controller.pauseAllServices();
      final countAtPause = callCount;
      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount, countAtPause);

      controller.resumeAllServices();
      await Future.delayed(Duration(milliseconds: 30));
      expect(callCount, greaterThan(countAtPause));

      controller.stopService('non-perm');
    });

    test('_LoopService deep pause/stop', () async {
      controller.startLoop('loop3', () async {
        await Future.delayed(Duration(milliseconds: 20));
      }, delay: Duration(milliseconds: 10));
      await Future.delayed(Duration(milliseconds: 10));
      controller.pauseService('loop3');
      await Future.delayed(Duration(milliseconds: 50));
      controller.stopService('loop3'); // Hits _resumeIfNeeded (189)
    });

    test('_IsolateLoopService exhaustive lifecycle', () async {
      controller.startIsolateLoop('iso3', () {
        // Loop body
      }, delay: Duration(milliseconds: 10));
      await Future.delayed(Duration(milliseconds: 100));
      controller.pauseService('iso3');
      await Future.delayed(Duration(milliseconds: 250));
      controller.resumeService('iso3'); // Hits 288
      await Future.delayed(Duration(milliseconds: 100));
      controller.pauseService('iso3');
      await Future.delayed(Duration(milliseconds: 250));
      controller.stopService('iso3'); // Hits 292-293
    });

    test('_IsolateLoopService error handling', () async {
      controller.startIsolateLoop('iso-err', () {
        throw Exception('Isolate error');
      }, delay: Duration(milliseconds: 10));

      await Future.delayed(Duration(milliseconds: 200));
      final status = controller.getServiceStatus('iso-err')?.value;
      expect(status, isA<LxError>()); // Hits 312 in Isolate loop
    });
  });
}
