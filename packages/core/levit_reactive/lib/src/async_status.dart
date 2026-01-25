part of '../levit_reactive.dart';

/// A sealed class hierarchy representing the status of an asynchronous operation.
///
/// [LxStatus] provides a type-safe way to represent the four standard states of
/// async state management:
/// 1.  [LxIdle]: The operation has not yet started.
/// 2.  [LxWaiting]: The operation is currently in progress.
/// 3.  [LxSuccess]: The operation completed successfully with a value.
/// 4.  [LxError]: The operation failed with an error.
///
/// ### Stale-While-Revalidate
/// All status types can optionally hold a [lastValue] of type [T]. This allows
/// the UI to display the previous successful data while a new operation is
/// in progress or after an error has occurred, preventing awkward loading
/// flickers.
sealed class LxStatus<T> {
  /// The most recent successful value of type [T], if any.
  final T? lastValue;

  /// Internal constructor for async status types.
  const LxStatus(this.lastValue);

  /// Returns `true` if the status is [LxWaiting].
  bool get isLoading => this is LxWaiting<T>;

  /// Returns `true` if the status is [LxSuccess].
  bool get hasValue => this is LxSuccess<T>;

  /// Returns `true` if the status is [LxError].
  bool get hasError => this is LxError<T>;

  /// Returns the value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
        LxSuccess<T>(:final value) => value,
        _ => null,
      };

  /// Returns the error if the status is [LxError], otherwise `null`.
  Object? get errorOrNull => switch (this) {
        LxError<T>(:final error) => error,
        _ => null,
      };

  /// Returns the stack trace if the status is [LxError], otherwise `null`.
  StackTrace? get stackTraceOrNull => switch (this) {
        LxError<T>(:final stackTrace) => stackTrace,
        _ => null,
      };
}

/// Status: Idle (the operation has not been initiated).
final class LxIdle<T> extends LxStatus<T> {
  static final Map<Type, LxIdle<dynamic>> _cache = {};

  /// Creates an idle status.
  ///
  /// Uses an internal cache for `null` [lastValue] instances to minimize allocations.
  factory LxIdle([T? lastValue]) {
    if (lastValue != null) {
      return LxIdle._internal(lastValue);
    }
    return _cache.putIfAbsent(T, () => LxIdle<T>._internal(null)) as LxIdle<T>;
  }

  const LxIdle._internal(super.lastValue);

  @override
  String toString() => 'LxIdle<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxIdle<T> && other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue);
}

/// Status: Waiting (the operation is active).
final class LxWaiting<T> extends LxStatus<T> {
  static final Map<Type, LxWaiting<dynamic>> _cache = {};

  /// Creates a waiting status.
  ///
  /// Uses an internal cache for `null` [lastValue] instances to minimize allocations.
  factory LxWaiting([T? lastValue]) {
    if (lastValue != null) {
      return LxWaiting._internal(lastValue);
    }
    return _cache.putIfAbsent(T, () => LxWaiting<T>._internal(null))
        as LxWaiting<T>;
  }

  const LxWaiting._internal(super.lastValue);

  @override
  String toString() => 'LxWaiting<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxWaiting<T> && other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue);
}

/// Status: Success (the operation completed with a result).
final class LxSuccess<T> extends LxStatus<T> {
  /// The resulting value of the operation.
  final T value;

  /// Creates a success status wrapper around [value].
  const LxSuccess(this.value) : super(value);

  @override
  String toString() => 'LxSuccess<$T>($value)';

  @override
  bool operator ==(Object other) =>
      other is LxSuccess<T> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Status: Error (the operation failed).
final class LxError<T> extends LxStatus<T> {
  /// The error object thrown during the operation.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace? stackTrace;

  /// Creates an error status optionally carrying the [lastValue].
  const LxError(this.error, [this.stackTrace, T? lastValue]) : super(lastValue);

  @override
  String toString() => 'LxError<$T>($error, lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxError<T> &&
      other.error == error &&
      other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, error, lastValue);
}

/// Ergonomic extensions for interacting with reactive async status sources.
extension LxStatusReactiveExtensions<T> on LxReactive<LxStatus<T>> {
  /// Returns the current value if the status is [LxSuccess], otherwise `null`.
  T? get valueOrNull => value.valueOrNull;

  /// Returns the current error if the status is [LxError], otherwise `null`.
  Object? get errorOrNull => value.errorOrNull;

  /// Returns the stack trace if the status is [LxError], otherwise `null`.
  StackTrace? get stackTraceOrNull => value.stackTraceOrNull;

  /// Returns `true` if the status is [LxIdle].
  bool get isIdle => value is LxIdle<T>;

  /// Returns `true` if the status is [LxWaiting].
  bool get isWaiting => value is LxWaiting<T>;

  /// Returns `true` if the status is [LxSuccess].
  bool get isSuccess => value is LxSuccess<T>;

  /// Returns `true` if the status is [LxError].
  bool get isError => value is LxError<T>;

  /// Alias for [isWaiting].
  bool get isLoading => isWaiting;

  /// Alias for [isSuccess].
  bool get hasValue => isSuccess;

  /// Returns the [LxStatus.lastValue] (the most recent successful value).
  T? get lastValue => value.lastValue;

  /// Force-retrieves the current value if the status is [LxSuccess].
  ///
  /// Throws the internal error if status is [LxError], or a [StateError] if
  /// the status is [LxIdle] or [LxWaiting].
  T get requireValue {
    final s = value;
    if (s is LxSuccess<T>) return s.value;
    if (s is LxError<T>) throw s.error;
    throw StateError('Async operation has no value yet (status: $s)');
  }

  /// Alias for [requireValue].
  T get computedValue => requireValue;

  /// Returns a Future that completes when the operation reaches a terminal state.
  ///
  /// If the current state is [LxSuccess] or [LxError], the Future completes
  /// immediately. Otherwise, it waits for the next transition to a terminal state.
  Future<T> get wait async {
    final s = value;
    if (s is LxSuccess<T>) return Future.value(s.value);
    if (s is LxError<T>) return Future.error(s.error, s.stackTrace);

    var first = await stream.first;

    if (first is LxSuccess<T>) return first.value;
    if (first is LxError<T>) throw first.error;

    throw StateError('Async operation has no value yet (status: $first)');
  }

  /// Specialized listen for async status that allows handling individual states.
  LxWorker<LxStatus<T>> listen(
    void Function(T value) onSuccess, {
    void Function()? onIdle,
    void Function()? onWaiting,
    void Function(Object error)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWorker.watchStatus<T>(
      this,
      onIdle: onIdle,
      onWaiting: onWaiting,
      onSuccess: onSuccess,
      onError: onError,
      onProcessingError: onProcessingError,
    );
  }
}
