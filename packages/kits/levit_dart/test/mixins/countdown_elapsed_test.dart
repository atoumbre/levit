import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

LevitCountdown countdown(
  FakeAsync time, {
  Duration duration = const Duration(seconds: 5),
  Duration interval = const Duration(seconds: 1),
  void Function(Duration)? onTick,
  void Function()? onFinish,
}) => LevitCountdown(
  totalDuration: duration,
  interval: interval,
  stopwatch: time.getClock(DateTime(2026)).stopwatch(),
  onTick: onTick,
  onFinish: onFinish,
);

void main() {
  test(
    'delayed callbacks catch up from elapsed time without replaying ticks',
    () {
      fakeAsync((time) {
        final ticks = <Duration>[];
        var finishes = 0;
        final timer = countdown(
          time,
          onTick: ticks.add,
          onFinish: () => finishes++,
        )..start();
        time.elapseBlocking(const Duration(milliseconds: 3500));
        time.elapse(Duration.zero);
        expect(timer.remaining.value, const Duration(milliseconds: 1500));
        expect(ticks, [const Duration(milliseconds: 1500)]);
        time.elapseBlocking(const Duration(seconds: 10));
        time.elapse(Duration.zero);
        expect(timer.remaining.value, Duration.zero);
        expect(ticks.last, Duration.zero);
        expect(ticks.length, 2);
        expect(finishes, 1);
        expect(timer.isRunning, isFalse);
        time.elapse(const Duration(hours: 1));
        expect(finishes, 1);
        timer.dispose();
        time.flushMicrotasks();
        expect(time.pendingTimers, isEmpty);
      });
    },
  );

  test(
    'final update uses the deadline rather than rounding up to an interval',
    () {
      fakeAsync((time) {
        var finishes = 0;
        final timer = countdown(
          time,
          duration: const Duration(milliseconds: 1250),
          onFinish: () => finishes++,
        )..start();
        time.elapse(const Duration(seconds: 1));
        expect(timer.remaining.value, const Duration(milliseconds: 250));
        time.elapse(const Duration(milliseconds: 250));
        expect(timer.remaining.value, Duration.zero);
        expect(finishes, 1);
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'pause accounts for sub-tick elapsed time and excludes time spent paused',
    () {
      fakeAsync((time) {
        var ticks = 0;
        var finishes = 0;
        final timer = countdown(
          time,
          onTick: (_) => ticks++,
          onFinish: () => finishes++,
        )..start();
        time.elapse(const Duration(milliseconds: 850));
        timer.pause();
        timer.pause();
        expect(timer.remaining.value, const Duration(milliseconds: 4150));
        expect(timer.isPaused, isTrue);
        expect(timer.isRunning, isFalse);
        expect(ticks, 0);
        expect(time.pendingTimers, isEmpty);
        time.elapse(const Duration(hours: 1));
        expect(timer.remaining.value, const Duration(milliseconds: 4150));
        timer.resume();
        timer.resume();
        time.elapse(const Duration(milliseconds: 4149));
        expect(finishes, 0);
        time.elapse(const Duration(milliseconds: 1));
        expect(timer.remaining.value, Duration.zero);
        expect(finishes, 1);
        timer.resume();
        expect(time.pendingTimers, isEmpty);
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'stop resets, resume stays idle, and start replaces a paused or running run',
    () {
      fakeAsync((time) {
        var finishes = 0;
        final timer = countdown(time, onFinish: () => finishes++);
        timer.pause();
        timer.resume();
        expect(time.pendingTimers, isEmpty);
        timer.start();
        time.elapse(const Duration(seconds: 2));
        timer.pause();
        timer.start();
        expect(timer.remaining.value, const Duration(seconds: 5));
        expect(timer.isPaused, isFalse);
        time.elapse(const Duration(seconds: 1));
        timer.stop();
        expect(timer.remaining.value, const Duration(seconds: 5));
        timer.resume();
        time.elapse(const Duration(seconds: 10));
        expect(finishes, 0);
        timer.start();
        time.elapse(const Duration(seconds: 1));
        timer.start();
        time.elapse(const Duration(seconds: 5));
        expect(finishes, 1);
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'zero duration completes asynchronously once and invalid durations fail',
    () {
      fakeAsync((time) {
        var finishes = 0;
        final timer = countdown(
          time,
          duration: Duration.zero,
          onFinish: () => finishes++,
        )..start();
        expect(finishes, 0);
        time.elapse(Duration.zero);
        expect(finishes, 1);
        expect(time.pendingTimers, isEmpty);
        expect(
          () => countdown(time, duration: const Duration(microseconds: -1)),
          throwsArgumentError,
        );
        expect(
          () => countdown(time, interval: Duration.zero),
          throwsArgumentError,
        );
        expect(
          () => countdown(time, interval: const Duration(microseconds: -1)),
          throwsArgumentError,
        );
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'restarting from onTick suppresses old completion and obsolete timers',
    () {
      fakeAsync((time) {
        var ticks = 0;
        var finishes = 0;
        late LevitCountdown timer;
        timer = countdown(
          time,
          duration: const Duration(seconds: 1),
          onTick: (_) {
            if (++ticks == 1) timer.start();
          },
          onFinish: () => finishes++,
        )..start();
        time.elapse(const Duration(seconds: 1));
        expect(finishes, 0);
        expect(time.pendingTimers.length, 1);
        time.elapse(const Duration(seconds: 1));
        expect(finishes, 1);
        expect(ticks, 2);
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'disposal from a remaining listener stops further notifications immediately',
    () {
      fakeAsync((time) {
        var calls = 0;
        final timer = countdown(
          time,
          onTick: (_) => calls++,
          onFinish: () => calls++,
        );
        timer.remaining.addListener(() => timer.dispose());
        timer.start();
        time.elapse(const Duration(seconds: 1));
        expect(calls, 0);
        expect(timer.isDisposed, isTrue);
        expect(timer.remaining.isDisposed, isTrue);
        expect(time.pendingTimers, isEmpty);
        expect(() => timer.start(), throwsStateError);
        expect(() => timer.pause(), throwsStateError);
        expect(() => timer.resume(), throwsStateError);
        expect(() => timer.stop(), throwsStateError);
        time.flushMicrotasks();
      });
    },
  );

  test('controller closure awaits countdown stream cleanup', () async {
    final owner = _TimeOwner();
    final timer = owner.startCountdown(duration: const Duration(seconds: 10));
    final other = owner.startCountdown(duration: const Duration(seconds: 10));
    final release = Completer<void>();
    final stream = StreamController<Duration>(onCancel: () => release.future);
    timer.remaining.bind(stream.stream);
    var closed = false;
    final closing = Future<void>.sync(owner.onClose).then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(timer.isDisposed, isTrue);
    expect(other.isDisposed, isTrue);
    expect(closed, isFalse);
    expect(
      () => owner.startCountdown(duration: const Duration(seconds: 1)),
      throwsStateError,
    );
    expect(identical(timer.dispose(), timer.dispose()), isTrue);
    release.complete();
    await closing;
    await stream.close();
    expect(closed, isTrue);
  });

  test(
    'pausing after an overdue deadline completes rather than extending the run',
    () {
      fakeAsync((time) {
        var finishes = 0;
        final timer = countdown(time, onFinish: () => finishes++)..start();
        time.elapseBlocking(const Duration(seconds: 8));
        timer.pause();
        expect(timer.remaining.value, Duration.zero);
        expect(timer.isPaused, isFalse);
        expect(finishes, 1);
        time.elapse(Duration.zero);
        expect(finishes, 1);
        timer.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'one failed cleanup does not prevent other countdowns from closing',
    () async {
      final owner = _TimeOwner();
      final first = owner.startCountdown(duration: const Duration(hours: 1));
      final second = owner.startCountdown(duration: const Duration(hours: 1));
      final release = Completer<void>();
      final broken = StreamController<Duration>(
        onCancel: () async => throw StateError('cancel failed'),
      );
      final draining = StreamController<Duration>(
        onCancel: () => release.future,
      );
      first.remaining.bind(broken.stream);
      second.remaining.bind(draining.stream);
      var completed = false;
      final observed = expectLater(
        Future<void>.sync(owner.onClose),
        throwsA(isA<LevitDisposalException>()),
      ).then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(first.isDisposed, isTrue);
      expect(second.isDisposed, isTrue);
      expect(completed, isFalse);
      release.complete();
      await observed;
      expect(second.remaining.isDisposed, isTrue);
      await broken.close();
      await draining.close();
    },
  );
  test(
    'preparation and countdown cleanup failures are both reported',
    () async {
      final owner = _FailingTimeOwner();
      final timer = owner.startCountdown(duration: const Duration(hours: 1));
      final broken = StreamController<Duration>(
        onCancel: () async => throw StateError('cancel failed'),
      );
      timer.remaining.bind(broken.stream);
      await expectLater(
        Future<void>.sync(owner.onClose),
        throwsA(
          isA<LevitDisposalException>()
              .having((error) => error.failures.length, 'both failures', 2)
              .having(
                (error) => error.failures.any(
                  (failure) => failure.error.toString().contains(
                    'earlier cleanup failed',
                  ),
                ),
                'preparation failure',
                isTrue,
              )
              .having(
                (error) => error.failures.any(
                  (failure) => failure.error is LxCleanupException,
                ),
                'countdown failure',
                isTrue,
              ),
        ),
      );
      expect(timer.isDisposed, isTrue);
      await broken.close();
    },
  );
}

class _TimeOwner extends LevitController with LevitTimeMixin {}

class _FailingPreparationOwner extends LevitController {
  @override
  FutureOr<void> onBeforeClose() async {
    await super.onBeforeClose();
    throw StateError('earlier cleanup failed');
  }
}

class _FailingTimeOwner extends _FailingPreparationOwner with LevitTimeMixin {}
