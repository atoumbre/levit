part of '../levit_reactive.dart';

/// Metrics and metadata for a particular [LxWorker] execution.
///
/// [LxWorkerStat] provides insights into the performance and behavior of a
/// reactive watcher. It tracks execution counts, durations, and asynchronous
/// state.
class LxWorkerStat {
  /// The total number of times the watcher callback has been executed.
  final int runCount;

  /// The duration of the most recent execution.
  final Duration lastDuration;

  /// The cumulative duration of all executions since the watcher was created.
  final Duration totalDuration;

  /// The timestamp of the last successful execution.
  final DateTime? lastRun;

  /// The most recent error encountered during execution, if any.
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

/// A reactive observer that executes a side-effect when a source changes.
///
/// [LxWorker] is the primary mechanism for reacting to state changes with
/// non-reactive code (e.g., logging, navigation, or database writes).
///
/// Unlike a standard [StreamSubscription], [LxWorker] provides:
/// 1.  **Observability**: It is itself an [LxReactive] that holds [LxWorkerStat].
/// 2.  **Monitoring**: Tracks execution performance and recognizes async gaps.
/// 3.  **Error Handling**: Provides dedicated hooks for synchronous and
///     asynchronous errors.
///
/// ### Usage
/// ```dart
/// final count = 0.lx;
/// final watcher = LxWorker(count, (v) => print('New value: $v'));
/// ```
class LxWorker<T> extends LxBase<LxWorkerStat> {
  /// The reactive source being monitored.
  final LxReactive<T> source;

  /// The callback to execute whenever the source notifies a change.
  final void Function(T value) callback;

  final Function(Object error, StackTrace stackTrace)? _onError;
  final Function(Object error, StackTrace stackTrace)? _onProcessingError;
  final bool? _enableMonitoring;

  StreamSubscription? _subscription;
  void Function()? _removeListener;

  /// Returns `true` if this watcher is capturing performance metrics.
  bool get isMonitoringEnabled => _enableMonitoring ?? Lx.enableWatchMonitoring;

  /// Creates a new watcher instance.
  LxWorker(
    this.source,
    this.callback, {
    Function(Object error, StackTrace stackTrace)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
    bool? enableMonitoring,
    String? name,
  })  : _onError = onError,
        _onProcessingError = onProcessingError,
        _enableMonitoring = enableMonitoring,
        super(const LxWorkerStat(), name: name) {
    _init();
  }

  void _init() {
    void executeCallback(T value) {
      final monitoring = isMonitoringEnabled;
      final start = monitoring ? DateTime.now() : null;

      try {
        final result = (callback as dynamic)(value);

        if (result is Future) {
          if (monitoring && (!this.value.isAsync || !this.value.isProcessing)) {
            updateValue((s) => s.copyWith(isAsync: true, isProcessing: true));
          }

          result.then((_) {
            if (monitoring) {
              final end = DateTime.now();
              final duration = end.difference(start!);
              updateValue((s) => s.copyWith(
                    runCount: s.runCount + 1,
                    lastDuration: duration,
                    totalDuration: s.totalDuration + duration,
                    lastRun: end,
                    isProcessing: false,
                    error: null,
                  ));
            }
          }).catchError((e, s) {
            _onProcessingError?.call(e, s);
            if (monitoring) {
              final end = DateTime.now();
              final duration = end.difference(start!);
              updateValue((s) => s.copyWith(
                    runCount: s.runCount + 1,
                    lastDuration: duration,
                    totalDuration: s.totalDuration + duration,
                    lastRun: end,
                    isProcessing: false,
                    error: e,
                  ));
            }
          });
        } else {
          if (monitoring) {
            final end = DateTime.now();
            final duration = end.difference(start!);
            updateValue((s) => s.copyWith(
                  runCount: s.runCount + 1,
                  lastDuration: duration,
                  totalDuration: s.totalDuration + duration,
                  lastRun: end,
                  isAsync: false,
                  isProcessing: false,
                  error: null,
                ));
          }
        }
      } catch (e, s) {
        _onProcessingError?.call(e, s);

        if (monitoring) {
          final end = DateTime.now();
          final duration = end.difference(start!);
          updateValue((s) => s.copyWith(
                runCount: s.runCount + 1,
                lastDuration: duration,
                totalDuration: s.totalDuration + duration,
                lastRun: end,
                isProcessing: false,
                error: e,
              ));
        }

        if (_onProcessingError == null) rethrow;
      }
    }

    if (_onError == null) {
      void listener() => executeCallback(source.value);
      source.addListener(listener);
      _removeListener = () => source.removeListener(listener);
    } else {
      _subscription = source.stream.listen(
        (val) => executeCallback(val),
        onError: _onError,
      );
    }
  }

  @override
  void close() {
    _removeListener?.call();
    _subscription?.cancel();
    super.close();
  }

  /// Triggers [callback] only when the boolean [source] becomes `true`.
  static LxWorker<bool> watchTrue(
    LxReactive<bool> source,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<bool>(
      source,
      (value) {
        if (value) callback();
      },
      onProcessingError: onProcessingError,
    );
  }

  /// Triggers [callback] only when the boolean [source] becomes `false`.
  static LxWorker<bool> watchFalse(
    LxReactive<bool> source,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<bool>(
      source,
      (value) {
        if (!value) callback();
      },
      onProcessingError: onProcessingError,
    );
  }

  /// Triggers [callback] only when [source] matches [targetValue].
  static LxWorker<T> watchValue<T>(
    LxReactive<T> source,
    T targetValue,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<T>(
      source,
      (value) {
        if (value == targetValue) callback();
      },
      onProcessingError: onProcessingError,
    );
  }

  /// Watches an async [source] and triggers callbacks for specific state transitions.
  static LxWorker<LxStatus<T>> watchStatus<T>(
    LxReactive<LxStatus<T>> source, {
    void Function()? onIdle,
    void Function()? onWaiting,
    void Function(T value)? onSuccess,
    void Function(Object error)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker<LxStatus<T>>(
      source,
      (status) {
        if (status is LxIdle<T>) {
          return onIdle?.call();
        } else if (status is LxWaiting<T>) {
          return onWaiting?.call();
        } else if (status is LxSuccess<T>) {
          return onSuccess?.call(status.value);
        } else if (status is LxError<T>) {
          return onError?.call(status.error);
        }
      },
      onProcessingError: onProcessingError,
    );
  }
}

/// Shorthand extensions for creating watchers on any reactive source.

extension LxReactiveWatchExtensions<T> on LxReactive<T> {
  /// Executes [callback] whenever this reactive value changes.
  ///
  /// Returns an [LxWorker] instance that can be used to monitor performance
  /// or manually closed.
  LxWorker<T> listen(void Function(T value) callback) {
    return LxWorker<T>(this, callback);
  }
}
