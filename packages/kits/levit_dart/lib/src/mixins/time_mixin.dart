import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';

/// A mixin for [LevitController] that centralizes time-based operations like
/// debouncing, throttling, intervals, and countdowns.
///
/// This unified mixin replaces separate debounce/periodic implementations
/// to ensure consistent lifecycle management and memory safety.
mixin LevitTimeMixin on LevitController {
  final _timers = <String, Timer>{};

  /// Debounces a [callback] function.
  ///
  /// *   [id]: A unique identifier for this operation.
  /// *   [duration]: The silence duration required before execution.
  /// *   [callback]: The function to execute.
  ///
  /// Each call resets the timer. The callback runs only after [duration]
  /// has passed without any new calls.
  void debounce(String id, Duration duration, void Function() callback) {
    _timers[id]?.cancel();
    _timers[id] = Timer(duration, () {
      _timers.remove(id);
      callback();
    });
  }

  /// Throttles a [callback] function.
  ///
  /// *   [id]: A unique identifier for this operation.
  /// *   [duration]: The lockout duration after execution.
  /// *   [callback]: The function to execute.
  ///
  /// Ensures the callback runs at most once every [duration].
  /// If called during the cool down period, the call is ignored.
  void throttle(String id, Duration duration, void Function() callback) {
    if (_timers.containsKey(id)) return;

    callback();
    _timers[id] = Timer(duration, () {
      _timers.remove(id);
    });
  }

  /// Starts a periodic interval timer.
  ///
  /// *   [id]: A unique identifier (required for cancellation).
  /// *   [duration]: The interval between executions.
  /// *   [callback]: The function to execute.
  ///
  /// Replaces `Timer.periodic`. Automatically cancelled on controller close.
  void startInterval(
      String id, Duration duration, void Function(Timer timer) callback) {
    _timers[id]?.cancel();
    _timers[id] = Timer.periodic(duration, callback);
  }

  /// Cancels a specific timer by [id].
  void cancelTimer(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  /// Cancels all active timers (debounce, throttle, interval).
  void cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Starts a reactive countdown.
  ///
  /// Returns an [LxCountdown] object that exposes the [LxCountdown.remaining]
  /// duration and control methods (pause, resume, stop).
  ///
  /// *   [duration]: The total duration to count down/up.
  /// *   [interval]: The tick interval (default: 1 second).
  /// *   [onTick]: Called on every interval.
  /// *   [onFinish]: Called when the countdown reaches zero.
  LxCountdown startCountdown({
    required Duration duration,
    Duration interval = const Duration(seconds: 1),
    void Function(Duration remaining)? onTick,
    void Function()? onFinish,
  }) {
    final countdown = LxCountdown(
      totalDuration: duration,
      interval: interval,
      onTick: onTick,
      onFinish: onFinish,
    );
    // Auto-dispose the countdown with the controller
    // Note: Since LxCountdown isn't a reactive itself but holds one, we rely on its dispose.
    // We can't use autoDispose() directly on it unless it's a Disposable.
    // Let's ensure LxCountdown implements Disposable or we track it.
    // For now, we return it and let the user manage or we track it internally if we want rigorous safety.
    // Better: Add to a list of disposables.
    // For simplicity in this mixin, we return it. Ideally, the user calls .dispose() or we track it.
    // To be safe, let's track it in a separate list.
    _countdowns.add(countdown);
    countdown.start();
    return countdown;
  }

  final _countdowns = <LxCountdown>[];

  @override
  void onClose() {
    cancelAllTimers();
    for (final c in _countdowns) {
      c.dispose();
    }
    _countdowns.clear();
    super.onClose();
  }
}

/// A reactive countdown timer.
class LxCountdown {
  final Duration totalDuration;
  final Duration interval;
  final void Function(Duration remaining)? onTick;
  final void Function()? onFinish;

  Timer? _timer;
  late final remaining = LxVar<Duration>(totalDuration);
  bool _isPaused = false;

  LxCountdown({
    required this.totalDuration,
    required this.interval,
    this.onTick,
    this.onFinish,
  });

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (timer) {
      if (_isPaused) return;

      final newRemaining = remaining.value - interval;
      if (newRemaining.isNegative) {
        remaining.value = Duration.zero;
        timer.cancel();
        onFinish?.call();
      } else {
        remaining.value = newRemaining;
        onTick?.call(newRemaining);
      }
    });
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    remaining.value =
        totalDuration; // Reset? Or keep at stopped val? Reset is usually 'stop'.
    _isPaused = false;
  }

  void dispose() {
    _timer?.cancel();
    remaining.close();
  }
}
