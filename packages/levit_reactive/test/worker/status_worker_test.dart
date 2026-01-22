import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStatus Watchers', () {
    test('watchStatus fires onSuccess', () async {
      final f = LxFuture<int>.idle();
      int? result;

      LxWatch.status<int>(f, onSuccess: (value) => result = value);

      f.restart(Future.value(42));
      await Future.microtask(() {});
      expect(result, 42);
    });

    test('watchStatus does not fire success for other statuses', () async {
      final f = LxFuture<int>.idle();
      int? result;

      LxWatch.status<int>(f, onSuccess: (value) => result = value);

      // Transition to Waiting
      f.restart(Future.delayed(Duration(seconds: 1), () => 10));
      await Future.microtask(() {});
      expect(result, null);
    });

    test('watchStatus fires onError', () async {
      final f = LxFuture<int>.idle();
      Object? error;

      LxWatch.status<int>(f, onError: (e) => error = e);

      f.restart(Future.error('Run failed'));
      await Future.microtask(() {});
      expect(error, 'Run failed');
    });

    test('watchStatus fires onWaiting', () async {
      final f = LxFuture<int>.idle();
      var waiting = false;

      LxWatch.status<int>(f, onWaiting: () => waiting = true);

      f.restart(Future.delayed(Duration(milliseconds: 50), () => 1));
      await Future.microtask(() {});
      expect(waiting, true);
    });

    test('watchStatus fires onIdle', () async {
      // Harder to test with LxFuture since it doesn't go back to idle easily
      // Use raw LxVar<LxStatus<int>>
      final s = LxVar<LxStatus<int>>(LxWaiting());
      var idle = false;

      LxWatch.status<int>(s, onIdle: () => idle = true);

      s.value = LxIdle();
      await Future.microtask(() {});
      expect(idle, true);
    });

    test('dispose cancels subscription', () async {
      final f = LxFuture<int>.idle();
      var count = 0;

      final dispose = LxWatch.status<int>(f, onSuccess: (_) => count++);

      f.restart(Future.value(1));
      await Future.microtask(() {});
      expect(count, 1);

      dispose.close();

      f.restart(Future.value(2));
      await Future.microtask(() {});
      expect(count, 1);
    });

    test('watchStatus fires correct callback', () async {
      final f = LxFuture<int>.idle();
      var log = <String>[];

      LxWatch.status<int>(
        f,
        onIdle: () => log.add('idle'),
        onWaiting: () => log.add('waiting'),
        onSuccess: (v) => log.add('success: $v'),
        onError: (e) => log.add('error: $e'),
      );

      // Verify transitions.

      f.restart(Future.value(1)); // waiting -> success
      await Future.microtask(() {});
      expect(log, contains('waiting'));
      expect(log.last, 'success: 1');

      log.clear();
      f.restart(Future.error('fail')); // waiting -> error
      await Future.microtask(() {});
      expect(log, contains('waiting'));
      expect(log.last, 'error: fail');
    });
    test('watchStatus alias coverage', () async {
      final lx = LxVar<LxStatus<int>>(LxIdle<int>());
      bool successCalled = false;
      bool waitingCalled = false;

      final unwatch = LxWatch.status<int>(
        lx,
        onSuccess: (v) => successCalled = true,
        onWaiting: () => waitingCalled = true,
      );

      // Transitions
      lx.value = LxWaiting<int>();
      await Future.microtask(() {});
      expect(waitingCalled, true);

      lx.value = const LxSuccess<int>(42);
      await Future.microtask(() {});
      expect(successCalled, true);

      unwatch();
    });
  });
}
