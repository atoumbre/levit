part of '../kit_library.dart';

/// A mixin for [LevitController] that manages debouncing, throttling,
/// periodic intervals, and reactive countdowns tied to the controller lifecycle.
///
/// Note that [debounce], [throttle], and [startInterval] share a single timer
/// ID namespace: reusing an `id` across them cancels any existing timer with
/// that ID. [cancelTimer] and [cancelAllTimers] affect only those timers, not
/// countdowns created with [startCountdown].
///
/// Timers and countdowns are cleaned up automatically during [onBeforeClose].
/// Subclasses overriding [onBeforeClose] must await `super.onBeforeClose()`.
///
/// ```dart
/// class SearchController extends LevitController with LevitTimeMixin {
///   final query = ''.lx;
///
///   void onQueryChanged(String value) {
///     query.value = value;
///     debounce('search', const Duration(milliseconds: 300), () {
///       runSearch(query());
///     });
///   }
/// }
/// ```
///
/// {@category Loops, Timers & Selection}
mixin LevitTimeMixin on LevitController {
  final _timers = <String, Timer>{};
  final _countdowns = <LevitCountdown>[];

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
  /// Executes [callback] immediately on the leading edge and ignores
  /// subsequent calls with the same [id] during the [duration] cooldown period.
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
    String id,
    Duration duration,
    void Function(Timer timer) callback,
  ) {
    _timers[id]?.cancel();
    _timers[id] = Timer.periodic(duration, callback);
  }

  /// Starts a reactive countdown and registers it for automatic cleanup when
  /// this controller closes.
  ///
  /// Returns a [LevitCountdown] that exposes [LevitCountdown.remaining]
  /// and control methods (`pause`, `resume`, `start`, `stop`). The countdown
  /// starts immediately.
  ///
  /// * [duration]: The non-negative total duration to count down.
  /// * [interval]: The positive maximum interval between updates (default: 1 second).
  /// * [onTick]: Called on each delivered update, including the terminal zero.
  /// * [onFinish]: Called when the countdown reaches zero.
  ///
  /// Throws a [StateError] if this controller is closing or disposed, or an
  /// [ArgumentError] if [duration] is negative or [interval] is not positive.
  LevitCountdown startCountdown({
    required Duration duration,
    Duration interval = const Duration(seconds: 1),
    void Function(Duration remaining)? onTick,
    void Function()? onFinish,
  }) {
    if (isClosing || isDisposed) {
      throw StateError('Cannot start a countdown on a closing controller.');
    }
    final countdown = LevitCountdown(
      totalDuration: duration,
      interval: interval,
      onTick: onTick,
      onFinish: onFinish,
    );
    // Countdown owns a reactive field internally, so this mixin tracks disposal explicitly.
    _countdowns.add(countdown);
    countdown.start();
    return countdown;
  }

  /// Cancels a specific timer created by [debounce], [throttle], or
  /// [startInterval] by [id]. Does not affect countdowns from [startCountdown].
  void cancelTimer(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  /// Cancels all active timers created by [debounce], [throttle], or
  /// [startInterval]. Does not affect countdowns from [startCountdown].
  void cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  FutureOr<void> onBeforeClose() async {
    final failures = <LevitDisposalFailure>[];
    try {
      await super.onBeforeClose();
    } catch (error, stack) {
      failures.add(
        LevitDisposalFailure(resource: this, error: error, stackTrace: stack),
      );
    }
    try {
      await _closeTimeResources();
    } catch (error, stack) {
      failures.add(
        LevitDisposalFailure(resource: this, error: error, stackTrace: stack),
      );
    }
    if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
  }

  Future<void> _closeTimeResources() async {
    cancelAllTimers();
    final failures = <LevitDisposalFailure>[];
    // Request cancellation for every countdown before awaiting any IO cleanup.
    final cleanup = _countdowns.map((countdown) {
      return Future<void>.sync(countdown.dispose).catchError((
        Object error,
        StackTrace stack,
      ) {
        failures.add(
          LevitDisposalFailure(
            resource: countdown,
            error: error,
            stackTrace: stack,
          ),
        );
      });
    }).toList();
    await Future.wait(cleanup);
    _countdowns.clear();
    if (failures.isNotEmpty) throw LevitDisposalException(failures);
  }
}

/// A countdown measured from elapsed time, independent of callback frequency.
///
/// The default clock is a monotonic [Stopwatch]. Delayed timer delivery catches
/// up on the next update; missed ticks are not replayed. [pause] freezes elapsed
/// time, including the fraction since the last tick, until [resume]. App lifecycle
/// changes do not pause it automatically: call these controls explicitly if wanted.
///
/// [start] begins a new run at [totalDuration]; [stop] resets without finishing.
/// Callbacks are synchronous. [dispose] cancels timing immediately and awaits
/// closure of [remaining]. A controller can own a standalone countdown with `own`.
///
/// {@category Loops, Timers & Selection}
class LevitCountdown implements LevitDisposable {
  /// The non-negative duration of each run.
  final Duration totalDuration;

  /// The positive maximum delay between published updates. The final update is
  /// scheduled at the remaining deadline when it is shorter than this interval.
  final Duration interval;

  /// Receives actual remaining time, once per delivered tick (including zero).
  final void Function(Duration remaining)? onTick;

  /// Called once when a run reaches zero. Stopping, restarting or disposing from
  /// the zero notification or [onTick] suppresses that run's remaining callbacks.
  final void Function()? onFinish;

  final Stopwatch _stopwatch;
  Timer? _timer;
  Future<void>? _closing;
  int _generation = 0;
  bool _isRunning = false;
  bool _isPaused = false;

  /// The last published duration. Use control methods to alter the countdown;
  /// assigning this reactive value does not change its elapsed-time clock.
  late final LxVar<Duration> remaining;

  /// Creates an idle countdown. [stopwatch] optionally supplies a deterministic
  /// clock for testing; this countdown exclusively starts, stops and resets it.
  /// A negative duration or a non-positive interval throws [ArgumentError].
  LevitCountdown({
    required this.totalDuration,
    required this.interval,
    this.onTick,
    this.onFinish,
    Stopwatch? stopwatch,
  }) : _stopwatch = stopwatch ?? Stopwatch() {
    if (totalDuration < Duration.zero) {
      throw ArgumentError.value(
        totalDuration,
        'totalDuration',
        'Must not be negative.',
      );
    }
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
    remaining = LxVar<Duration>(totalDuration);
  }

  /// Whether elapsed time currently counts toward completion.
  bool get isRunning => _isRunning;

  /// Whether an unfinished run is explicitly paused.
  bool get isPaused => _isPaused;

  /// Whether disposal has started; new control operations then throw.
  bool get isDisposed => _closing != null;

  void _ensureActive() {
    if (isDisposed) throw StateError('Countdown is disposed.');
  }

  Duration get _currentRemaining {
    final value = totalDuration - _stopwatch.elapsed;
    return value > Duration.zero ? value : Duration.zero;
  }

  bool _isCurrent(int generation) => !isDisposed && generation == _generation;

  /// Starts a fresh run, replacing any previous run or paused state.
  /// Zero-duration runs complete asynchronously on the next timer turn.
  void start() {
    _ensureActive();
    final generation = ++_generation;
    _timer?.cancel();
    _stopwatch
      ..stop()
      ..reset()
      ..start();
    _isRunning = true;
    _isPaused = false;
    remaining.value = totalDuration;
    if (_isCurrent(generation) && _isRunning) _schedule(generation);
  }

  void _schedule(int generation) {
    final left = _currentRemaining;
    _timer = Timer(left < interval ? left : interval, () {
      if (!_isCurrent(generation) || !_isRunning) return;
      _timer = null;
      try {
        _publish(generation, tick: true);
      } finally {
        if (_isCurrent(generation) && _isRunning) _schedule(generation);
      }
    });
  }

  void _publish(int generation, {required bool tick}) {
    final left = _currentRemaining;
    final finished = left == Duration.zero;
    if (finished) {
      _timer?.cancel();
      _timer = null;
      _stopwatch.stop();
      _isRunning = false;
      _isPaused = false;
    }
    remaining.value = left;
    if (!_isCurrent(generation)) return;
    try {
      if (tick || finished) onTick?.call(left);
    } finally {
      if (finished && _isCurrent(generation)) onFinish?.call();
    }
  }

  /// Freezes elapsed time and publishes the exact remaining duration without an
  /// extra tick callback. If the deadline already passed, completes the run.
  /// Has no effect when idle, completed or already paused.
  void pause() {
    _ensureActive();
    if (!_isRunning) return;
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _isRunning = false;
    _isPaused = true;
    _publish(generation, tick: false);
  }

  /// Continues a paused run, excluding all time spent paused. Has no effect when
  /// idle, completed or already running; use [start] to begin a new run.
  void resume() {
    _ensureActive();
    if (!_isPaused) return;
    _isPaused = false;
    _isRunning = true;
    final generation = ++_generation;
    _stopwatch.start();
    _schedule(generation);
  }

  /// Cancels the current run and resets the published duration without calling
  /// [onTick] or [onFinish]. Call [start] to run again.
  void stop() {
    _ensureActive();
    _generation++;
    _timer?.cancel();
    _timer = null;
    _stopwatch
      ..stop()
      ..reset();
    _isRunning = false;
    _isPaused = false;
    remaining.value = totalDuration;
  }

  /// Cancels timing immediately and awaits reactive cleanup. Repeated calls
  /// return the same completion; the source is closed even when never started.
  @override
  Future<void> dispose() {
    if (_closing != null) return _closing!;
    final completion = Completer<void>();
    _closing = completion.future;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _isRunning = false;
    _isPaused = false;
    completion.complete(Future<void>.sync(remaining.close));
    return _closing!;
  }
}
