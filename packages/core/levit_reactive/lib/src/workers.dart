part of '../levit_reactive.dart';

/// Performance metrics for an [LxWorker].
///
/// Tracks execution frequency, duration, and error states.
/// Useful for profiling side-effects.
class LxWorkerStat {
  /// How many times the worker callback has run.
  final int runCount;

  /// The duration of the last execution.
  final Duration lastDuration;

  /// The cumulative duration of all executions.
  final Duration totalDuration;

  /// The time of the last execution.
  final DateTime? lastRun;

  /// The last error that occurred during execution.
  final Object? error;

  /// Whether the callback is recognized as asynchronous (returns a [Future]).
  final bool isAsync;

  /// Whether an asynchronous callback is currently pending completion.
  final bool isProcessing;

  /// Creates a statistics snapshot.
  const LxWorkerStat({
    this.runCount = 0,
    this.lastDuration = Duration.zero,
    this.totalDuration = Duration.zero,
    this.lastRun,
    this.error,
    this.isAsync = false,
    this.isProcessing = false,
  });

  /// Creates a copy of the statistics with updated fields.
  LxWorkerStat copyWith({
    int? runCount,
    Duration? lastDuration,
    Duration? totalDuration,
    DateTime? lastRun,
    Object? error,
    bool? isAsync,
    bool? isProcessing,
  }) {
    return LxWorkerStat(
      runCount: runCount ?? this.runCount,
      lastDuration: lastDuration ?? this.lastDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      lastRun: lastRun ?? this.lastRun,
      error: error ?? this.error,
      isAsync: isAsync ?? this.isAsync,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  String toString() {
    return 'LxWorkerStat(runCount: $runCount, lastDuration: $lastDuration, isProcessing: $isProcessing, error: $error)';
  }
}

/// A reactive observer for side-effects.
///
/// [LxWorker] executes a callback whenever a [source] reactive changes.
/// Unlike [LxComputed], it does not produce a new value but performs an action
/// (e.g., logging, navigation, saving to DB).
///
/// // Example usage:
/// ```dart
/// final count = 0.lx;
///
/// // Log every change
/// final worker = LxWorker(count, (v) => print('Changed: $v'));
/// ```
class LxWorker<T> extends LxBase<LxWorkerStat>
    with _LxAsyncLifecycle<LxWorkerStat> {
  /// The observed value. This worker borrows its source.
  final LxReadable<T> source;
  final FutureOr<void> Function(T value, LxExecutionContext context) _callback;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final void Function(Object error, StackTrace stackTrace)? _onProcessingError;
  final bool? _enableMonitoring;

  /// Latest requests cooperative cancellation of earlier callbacks.
  /// Exhaust-latest runs one callback and retains one trailing value.
  final LxAsyncConcurrency concurrency;
  StreamSubscription<T>? _subscription;
  void Function()? _removeListener;
  bool _executionRunning = false;
  bool _trailingExecutionRequested = false;
  late T _trailingValue;

  bool get isMonitoringEnabled => _enableMonitoring ?? Lx.enableWatchMonitoring;

  /// Observes [source], tracking asynchronous callback completion.
  LxWorker(
    this.source,
    FutureOr<void> Function(T value) callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(Object error, StackTrace stackTrace)? onProcessingError,
    bool? enableMonitoring,
    String? name,
    this.concurrency = LxAsyncConcurrency.latest,
  }) : _callback = ((value, _) => callback(value)),
       _onError = onError,
       _onProcessingError = onProcessingError,
       _enableMonitoring = enableMonitoring,
       super(const LxWorkerStat(), name: name) {
    _init();
  }

  /// Observes [source] with an explicit per-execution cancellation context.
  LxWorker.withContext(
    this.source,
    this._callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(Object error, StackTrace stackTrace)? onProcessingError,
    bool? enableMonitoring,
    String? name,
    this.concurrency = LxAsyncConcurrency.latest,
  }) : _onError = onError,
       _onProcessingError = onProcessingError,
       _enableMonitoring = enableMonitoring,
       super(const LxWorkerStat(), name: name) {
    _init();
  }

  void _init() {
    if (_onError == null) {
      void listener() => _requestExecution(source.value);
      source.addListener(listener);
      _removeListener = () => source.removeListener(listener);
    } else {
      _subscription = source.stream.listen(
        _requestExecution,
        onError: _onError,
      );
    }
  }

  void _requestExecution(T value) {
    if (_workCancelled || isDisposed) return;
    if (concurrency == LxAsyncConcurrency.exhaustLatest && _executionRunning) {
      _trailingExecutionRequested = true;
      _trailingValue = value;
      return;
    }
    final context = _newExecution(
      cancelPrevious: concurrency == LxAsyncConcurrency.latest,
    );
    _executionRunning = true;
    final monitoring = isMonitoringEnabled;
    final clock = monitoring ? (Stopwatch()..start()) : null;
    void finish({Object? error, bool asynchronous = false}) {
      _executionContexts.remove(context);
      if (monitoring && !isDisposed && !_workCancelled) {
        final duration = clock!.elapsed;
        _setValueInternal(
          LxWorkerStat(
            runCount: this.value.runCount + 1,
            lastDuration: duration,
            totalDuration: this.value.totalDuration + duration,
            lastRun: DateTime.now(),
            error: error,
            isAsync: asynchronous,
            isProcessing: _executionContexts.isNotEmpty,
          ),
        );
      }
      _executionRunning = false;
      if (_trailingExecutionRequested && !_workCancelled && !isDisposed) {
        _trailingExecutionRequested = false;
        _requestExecution(_trailingValue);
      }
    }

    try {
      final result = context._run(() => _callback(value, context));
      if (result is Future) {
        if (monitoring && !isDisposed && !_workCancelled) {
          _setValueInternal(
            this.value.copyWith(isAsync: true, isProcessing: true),
          );
        }
        _trackWork(
          result.then<void>(
            (_) => finish(asynchronous: true),
            onError: (Object error, StackTrace stack) {
              finish(error: error, asynchronous: true);
              if (error is! LxCancelledException) {
                _onProcessingError?.call(error, stack);
              }
            },
          ),
          context,
        );
      } else {
        finish();
      }
    } catch (error, stack) {
      finish(error: error);
      if (_onProcessingError != null) {
        _onProcessingError(error, stack);
      } else if (error is! LxCancelledException) {
        rethrow;
      }
    }
  }

  @override
  void requestCancel() {
    if (_workCancelled) return;
    super.requestCancel();
    _trailingExecutionRequested = false;
    _removeListener?.call();
    _removeListener = null;
    final cancellation = _subscription?.cancel();
    _subscription = null;
    if (cancellation != null) _trackWork(cancellation);
  }

  /// Triggers [callback] when a boolean [source] becomes `true`.
  static LxWorker<bool> watchTrue(
    LxReadable<bool> source,
    FutureOr<void> Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<bool>(source, (value) {
      if (value) return callback();
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] when a boolean [source] becomes `false`.
  static LxWorker<bool> watchFalse(
    LxReadable<bool> source,
    FutureOr<void> Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<bool>(source, (value) {
      if (!value) return callback();
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] when [source] equals [targetValue].
  static LxWorker<T> watchValue<T>(
    LxReadable<T> source,
    T targetValue,
    FutureOr<void> Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<T>(source, (value) {
      if (value == targetValue) return callback();
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] only when [source] transitions from `false` to `true`.
  static LxWorker<bool> onRising(
    LxReadable<bool> source,
    FutureOr<void> Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    var previous = source.value;
    return LxWorker<bool>(source, (value) {
      final didRise = !previous && value;
      previous = value;
      if (didRise) return callback();
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] only when [source] transitions from `true` to `false`.
  static LxWorker<bool> onFalling(
    LxReadable<bool> source,
    FutureOr<void> Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    var previous = source.value;
    return LxWorker<bool>(source, (value) {
      final didFall = previous && !value;
      previous = value;
      if (didFall) return callback();
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] when [source] emits a value distinct from the previous one.
  ///
  /// Useful when values may be re-notified without changing
  /// (for example via manual refresh calls).
  static LxWorker<T> onChangeDistinct<T>(
    LxReadable<T> source,
    FutureOr<void> Function(T value) callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    var previous = source.value;
    return LxWorker<T>(source, (value) {
      if (value == previous) return null;
      previous = value;
      return callback(value);
    }, onProcessingError: onProcessingError);
  }

  /// Triggers [callback] after [duration] has passed without new source updates.
  static LxWorker<T> debounce<T>(
    LxReadable<T> source,
    Duration duration,
    FutureOr<void> Function(T value) callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<T>.withContext(
      source,
      (value, context) async {
        final ready = Completer<void>();
        final timer = Timer(duration, ready.complete);
        unawaited(
          context.cancelled.then((_) {
            timer.cancel();
            if (!ready.isCompleted) ready.complete();
          }),
        );
        await ready.future;
        if (!context.isCancelled) await callback(value);
      },
      onProcessingError: onProcessingError ?? Zone.current.handleUncaughtError,
    );
  }

  /// Runs immediately and ignores updates during the throttle interval.
  static LxWorker<T> throttle<T>(
    LxReadable<T> source,
    Duration duration,
    FutureOr<void> Function(T value) callback, {
    void Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    final clock = Stopwatch()..start();
    Duration? last;
    return LxWorker<T>(
      source,
      (value) {
        final now = clock.elapsed;
        if (last != null && now - last! < duration) return null;
        last = now;
        return callback(value);
      },
      onProcessingError: onProcessingError ?? Zone.current.handleUncaughtError,
    );
  }

  /// Triggers callbacks based on status changes of an async [source].
  static LxWorker<LxStatus<T>> watchStatus<T>(
    LxReadable<LxStatus<T>> source, {
    FutureOr<void> Function()? onIdle,
    FutureOr<void> Function()? onWaiting,
    FutureOr<void> Function(T value)? onSuccess,
    FutureOr<void> Function(Object error)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<LxStatus<T>>(source, (status) {
      if (status is LxIdle<T>) {
        return onIdle?.call();
      } else if (status is LxWaiting<T>) {
        return onWaiting?.call();
      } else if (status is LxSuccess<T>) {
        return onSuccess?.call(status.value);
      } else if (status is LxError<T>) {
        return onError?.call(status.error);
      }
    }, onProcessingError: onProcessingError);
  }
}

/// Extensions for creating watchers from any reactive source.
extension LxReactiveWatchExtensions<T> on LxReadable<T> {
  /// Attaches a listener to this reactive value.
  ///
  /// Returns an [LxWorker] which can be used to control the subscription.
  LxWorker<T> listen(FutureOr<void> Function(T value) callback) {
    return LxWorker<T>(this, callback);
  }
}
