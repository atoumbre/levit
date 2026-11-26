part of 'reactive_library.dart';

/// A sealed hierarchy representing the status of an asynchronous operation.
///
/// [LxStatus] provides a type-safe way to represent the standard states of
/// asynchronous operations: [LxIdle], [LxWaiting], [LxSuccess], and [LxError].
/// It supports "stale-while-revalidate" by optionally holding a [lastValue].
///
/// {@category Reactive State}
sealed class LxStatus<T> {
  /// The most recent successful value of type [T], if any.
  final T? lastValue;

  /// Internal constructor for async status types.
  const LxStatus(this.lastValue, {bool? hasLastValue})
    : hasLastValue = hasLastValue ?? lastValue != null;

  /// Whether retained data exists, independently of whether its value is null.
  final bool hasLastValue;

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
///
/// {@category Reactive State}
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

  /// Explicit retained data, including a successful null value.
  const LxIdle.retained(T lastValue) : super(lastValue, hasLastValue: true);

  /// Preserves the presence of previous data across status transitions.
  factory LxIdle.fromPrevious(LxStatus<T> previous) => previous.hasLastValue
      ? LxIdle.retained(previous.lastValue as T)
      : LxIdle<T>();

  @override
  String toString() => 'LxIdle<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxIdle<T> &&
      other.lastValue == lastValue &&
      other.hasLastValue == hasLastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue, hasLastValue);
}

/// Status: Waiting (the operation is active).
///
/// {@category Reactive State}
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

  /// Explicit retained data, including a successful null value.
  const LxWaiting.retained(T lastValue) : super(lastValue, hasLastValue: true);

  /// Preserves the presence of previous data across status transitions.
  factory LxWaiting.fromPrevious(LxStatus<T> previous) => previous.hasLastValue
      ? LxWaiting.retained(previous.lastValue as T)
      : LxWaiting<T>();

  @override
  String toString() => 'LxWaiting<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxWaiting<T> &&
      other.lastValue == lastValue &&
      other.hasLastValue == hasLastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue, hasLastValue);
}

/// Status: Success (the operation completed with a result).
///
/// {@category Reactive State}
final class LxSuccess<T> extends LxStatus<T> {
  /// The resulting value of the operation.
  final T value;

  /// Creates a success status wrapper around [value].
  const LxSuccess(this.value) : super(value, hasLastValue: true);

  @override
  String toString() => 'LxSuccess<$T>($value)';

  @override
  bool operator ==(Object other) =>
      other is LxSuccess<T> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Status: Error (the operation failed).
///
/// {@category Reactive State}
final class LxError<T> extends LxStatus<T> {
  /// The error object thrown during the operation.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace? stackTrace;

  /// Creates an error status optionally carrying the [lastValue].
  const LxError(this.error, [this.stackTrace, T? lastValue]) : super(lastValue);

  /// Creates an error status explicitly retaining [lastValue] (even when
  /// [lastValue] is `null` for a nullable type `T`).
  const LxError.retained(this.error, T lastValue, [this.stackTrace])
    : super(lastValue, hasLastValue: true);

  /// Creates an error status carrying over [LxStatus.lastValue] from [previous]
  /// if [previous] retained a value.
  factory LxError.fromPrevious(
    Object error,
    StackTrace? stack,
    LxStatus<T> previous,
  ) => previous.hasLastValue
      ? LxError.retained(error, previous.lastValue as T, stack)
      : LxError(error, stack);

  @override
  String toString() => 'LxError<$T>($error, lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxError<T> &&
      other.error == error &&
      other.lastValue == lastValue &&
      other.hasLastValue == hasLastValue;

  @override
  int get hashCode => Object.hash(runtimeType, error, lastValue, hasLastValue);
}

/// Ergonomic extensions for interacting with reactive async status sources.
///
/// {@category Reactive State}
extension LxStatusReactiveExtensions<T> on LxReadable<LxStatus<T>> {
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

  /// Whether [lastValue] holds a retained previous successful value (useful
  /// when `T` is nullable).
  bool get hasLastValue => value.hasLastValue;

  /// Force-retrieves the current value if the status is [LxSuccess].
  ///
  /// Throws the internal error if status is [LxError], or a [StateError] if
  /// the status is [LxIdle] or [LxWaiting].
  T get requireValue {
    final s = value;
    if (s is LxSuccess<T>) return s.value;
    if (s is LxError<T>) throw s.error;
    final sensitive = this is LxReactive && (this as LxReactive).isSensitive;
    final statusLabel = sensitive ? '${s.runtimeType}(***)' : '$s';
    throw StateError('Async operation has no value yet (status: $statusLabel)');
  }

  /// Returns a [Future] that completes when the operation reaches a terminal state.
  ///
  /// If the current state is [LxSuccess] or [LxError], the [Future] completes
  /// immediately. Otherwise, it waits for the next transition to a terminal
  /// state, throwing a [StateError] if the stream closes first.
  Future<T> get wait async {
    final s = value;
    if (s is LxSuccess<T>) return Future.value(s.value);
    if (s is LxError<T>) return Future.error(s.error, s.stackTrace);

    final terminalStatus = await stream.firstWhere(
      (status) => status is LxSuccess<T> || status is LxError<T>,
      orElse: () =>
          throw StateError('Async operation stream closed unexpectedly.'),
    );

    if (terminalStatus is LxSuccess<T>) return terminalStatus.value;
    throw (terminalStatus as LxError<T>).error;
  }

  /// Creates an [LxWorker] dispatching callbacks by [LxStatus] variant.
  ///
  /// The caller owns the returned [LxWorker] and must `own(...)` or `close()`
  /// it when no longer needed.
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
