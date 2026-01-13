import 'dart:async';

import 'core.dart';
import 'async_status.dart';
import 'computed.dart';
import 'global_accessor.dart';

// ============================================================================
// LxWatch Models
// ============================================================================

/// Statistics for a [LxWatch] execution.
///
/// Unlike other reactive sources, [LxWatch] is not geared toward the value it is watching
/// but rather toward the execution of the callback.
///
/// It does not extends LxReactive<[LxStatus]> like [LxComputed] and [LxComputed].
/// Instead, it is  a [LxReactive] holding execution metrics ([LxWatchStat]),
/// enabling management, monitoring, performance tracking, and debugging.
class LxWatchStat {
  /// How many times the watcher has triggered.
  final int runCount;

  /// Duration of the last execution.
  final Duration lastDuration;

  /// Accumulated duration of all executions.
  final Duration totalDuration;

  /// Timestamp of the last execution completion.
  final DateTime? lastRun;

  /// Most recent error, if any.
  final Object? error;

  /// Whether the watcher detected an async callback (returned a Future).
  final bool isAsync;

  /// Whether an async callback is currently executing.
  final bool isProcessing;

  const LxWatchStat({
    this.runCount = 0,
    this.lastDuration = Duration.zero,
    this.totalDuration = Duration.zero,
    this.lastRun,
    this.error,
    this.isAsync = false,
    this.isProcessing = false,
  });

  LxWatchStat copyWith({
    int? runCount,
    Duration? lastDuration,
    Duration? totalDuration,
    DateTime? lastRun,
    Object? error,
    bool? isAsync,
    bool? isProcessing,
  }) {
    return LxWatchStat(
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
    return 'LxWatchStat(runCount: $runCount, lastDuration: $lastDuration, isProcessing: $isProcessing, error: $error)';
  }
}

// ============================================================================
// LxWatch Class
// ============================================================================

/// A reactive watcher that tracks its execution statistics.
///
/// Wraps a subscription to a [LxReactive] source and executes a callback
/// when the source changes. Unlike a raw subscription, [LxWatch] is itself
/// a [LxReactive] holding execution metrics ([LxWatchStat]), enabling
/// monitoring, performance tracking, and debugging.
///
/// To dispose the watcher, call `.close()` or rely on [Lx] auto-disposal mechanisms.
class LxWatch<T> extends LxBase<LxWatchStat> {
  final LxReactive<T> source;
  final void Function(T value) callback;
  final Function(Object error, StackTrace stackTrace)? _onError;
  final Function(Object error, StackTrace stackTrace)? _onProcessingError;

  /// Whether performance monitoring is enabled for this watcher.
  ///
  /// If `null`, uses the global [Lx.enableWatchMonitoring] setting.
  /// If explicitly set, overrides the global setting.
  final bool? _enableMonitoring;

  StreamSubscription? _subscription;
  void Function()? _removeListener;

  /// Whether this watcher is actively tracking performance metrics.
  ///
  /// Returns the per-watcher setting if explicitly set, otherwise
  /// falls back to [Lx.enableWatchMonitoring].
  bool get isMonitoringEnabled => _enableMonitoring ?? Lx.enableWatchMonitoring;

  LxWatch(
    this.source,
    this.callback, {
    Function(Object error, StackTrace stackTrace)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
    bool? enableMonitoring,
    String? name,
  })  : _onError = onError,
        _onProcessingError = onProcessingError,
        _enableMonitoring = enableMonitoring,
        super(const LxWatchStat(), name: name) {
    _init();
  }

  void _init() {
    void executeCallback(T value) {
      final monitoring = isMonitoringEnabled;
      final start = monitoring ? DateTime.now() : null;

      try {
        final result = (callback as dynamic)(value);

        if (result is Future) {
          // Detected Async
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
            if (_onProcessingError != null) {
              _onProcessingError!(e, s);
            }
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
          // Synchronous
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
        if (_onProcessingError != null) {
          _onProcessingError!(e, s);
        }

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
      void listener() {
        executeCallback(source.value);
      }

      source.addListener(listener);
      _removeListener = () => source.removeListener(listener);
    } else {
      _subscription = source.stream.listen(
        (val) {
          executeCallback(val);
        },
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

  // ============================================================================
// Convenience watchers
// ============================================================================

  /// Watches [source] and calls [callback] when it becomes true.
  ///
  /// Useful for triggering one-off actions or navigation when a boolean condition is met.
  static LxWatch<bool> isTrue(
    LxReactive<bool> source,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWatch<bool>(
      source,
      (value) {
        if (value) return callback();
      },
      onProcessingError: onProcessingError,
    );
  }

  /// Watches [source] and calls [callback] when it becomes false.
  ///
  /// Useful for triggering actions when a boolean condition is no longer met.
  static LxWatch<bool> isFalse(
    LxReactive<bool> source,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWatch<bool>(
      source,
      (value) {
        if (!value) return callback();
      },
      onProcessingError: onProcessingError,
    );
  }

  /// Watches [source] and calls [callback] when it matches [targetValue].
  ///
  /// Triggers whenever [source] updates to a value equal to [targetValue].
  static LxWatch<T> isValue<T>(
    LxReactive<T> source,
    T targetValue,
    void Function() callback, {
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWatch<T>(
      source,
      (value) {
        if (value == targetValue) return callback();
      },
      onProcessingError: onProcessingError,
    );
  }

// ============================================================================
// LxStatus specialized watchers
// ============================================================================

  /// Watches an [LxStatus] source and calls specific callbacks for each state.
  ///
  /// This is a convenient way to handle side effects based on the status of an
  /// asynchronous operation (e.g., showing a toast on error, navigating on success).
  static LxWatch<LxStatus<T>> status<T>(
    LxReactive<LxStatus<T>> source, {
    void Function()? onIdle,
    void Function()? onWaiting,
    void Function(T value)? onSuccess,
    void Function(Object error)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWatch<LxStatus<T>>(
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
