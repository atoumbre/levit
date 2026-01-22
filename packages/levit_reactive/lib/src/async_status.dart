// ============================================================================
// LxStatus - Async Status Types
// ============================================================================

import 'core.dart';
import 'watchers.dart';

/// Sealed class representing the state of an asynchronous operation.
///
/// Used by [LxFuture] and [LxStream] to track loading, success, and error states.
sealed class LxStatus<T> {
  /// The last known successful value.
  ///
  /// Persists across loading and error states to allow "optimistic UI" patterns.
  final T? lastValue;

  const LxStatus(this.lastValue);

  /// Whether the status is [LxWaiting].
  bool get isLoading => this is LxWaiting<T>;

  /// Whether the status is [LxSuccess].
  bool get hasValue => this is LxSuccess<T>;

  /// Whether the status is [LxError].
  bool get hasError => this is LxError<T>;

  /// Returns the value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
        LxSuccess<T>(:final value) => value,
        _ => null,
      };

  /// Returns the error if failed, otherwise `null`.
  Object? get errorOrNull => switch (this) {
        LxError<T>(:final error) => error,
        _ => null,
      };

  /// Returns the stack trace if failed, otherwise `null`.
  StackTrace? get stackTraceOrNull => switch (this) {
        LxError<T>(:final stackTrace) => stackTrace,
        _ => null,
      };
}

/// Status: Idle (not started).
///
/// Represents the initial state before an operation begins.
final class LxIdle<T> extends LxStatus<T> {
  /// Singleton cache for LxIdle instances without lastValue.
  /// Key is the type T's hashCode (since we can't use Type directly as generic).
  static final Map<Type, LxIdle<dynamic>> _cache = {};

  /// Creates an idle status, optionally with a [lastValue].
  ///
  /// When [lastValue] is null, returns a cached singleton instance
  /// to reduce allocations in hot paths.
  factory LxIdle([T? lastValue]) {
    if (lastValue != null) {
      return LxIdle._internal(lastValue);
    }
    // Return cached singleton for this type
    return _cache.putIfAbsent(T, () => LxIdle<T>._internal(null)) as LxIdle<T>;
  }

  /// Internal constructor for creating instances.
  const LxIdle._internal(super.lastValue);

  @override
  String toString() => 'LxIdle<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxIdle<T> && other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue);
}

/// Status: Waiting (loading/executing).
///
/// Represents an ongoing asynchronous operation.
final class LxWaiting<T> extends LxStatus<T> {
  /// Singleton cache for LxWaiting instances without lastValue.
  static final Map<Type, LxWaiting<dynamic>> _cache = {};

  /// Creates a waiting status.
  ///
  /// When [lastValue] is null, returns a cached singleton instance
  /// to reduce allocations in hot paths.
  factory LxWaiting([T? lastValue]) {
    if (lastValue != null) {
      return LxWaiting._internal(lastValue);
    }
    // Return cached singleton for this type
    return _cache.putIfAbsent(T, () => LxWaiting<T>._internal(null))
        as LxWaiting<T>;
  }

  /// Internal constructor for creating instances.
  const LxWaiting._internal(super.lastValue);

  @override
  String toString() => 'LxWaiting<$T>(lastValue: $lastValue)';

  @override
  bool operator ==(Object other) =>
      other is LxWaiting<T> && other.lastValue == lastValue;

  @override
  int get hashCode => Object.hash(runtimeType, lastValue);
}

/// Status: Success (completed with value).
///
/// Represents a successfully completed operation.
final class LxSuccess<T> extends LxStatus<T> {
  /// The successful value.
  final T value;

  /// Creates a success status.
  const LxSuccess(this.value) : super(value);

  @override
  String toString() => 'LxSuccess<$T>($value)';

  @override
  bool operator ==(Object other) =>
      other is LxSuccess<T> && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// Status: Error (failed).
///
/// Represents a failed operation.
final class LxError<T> extends LxStatus<T> {
  /// The error object.
  final Object error;

  /// The stack trace.
  final StackTrace? stackTrace;

  /// Creates a new [LxError] with the given [error] and optional [stackTrace].
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

// ============================================================================
// LxStatus Extensions
// ============================================================================

/// Extensions for reactive async status.
extension LxVarExtensions<T> on LxReactive<T> {
  LxWatch<T> listen(
    void Function(T value) callback,
  ) {
    return LxWatch(
      this,
      callback,
    );
  }
}

/// Extensions for reactive async status.
extension LxStatusReactiveExtensions<T> on LxReactive<LxStatus<T>> {
  /// Returns the value if success, else `null`.
  T? get valueOrNull => value.valueOrNull;

  /// Returns the error if error, else `null`.
  Object? get errorOrNull => value.errorOrNull;

  /// Returns the stack trace if error, else `null`.
  StackTrace? get stackTraceOrNull => value.stackTraceOrNull;

  /// Whether idle.
  bool get isIdle => value is LxIdle<T>;

  /// Whether waiting.
  bool get isWaiting => value is LxWaiting<T>;

  /// Whether success.
  bool get isSuccess => value is LxSuccess<T>;

  /// Whether error.
  bool get isError => value is LxError<T>;

  /// Alias for [isWaiting].
  bool get isLoading => isWaiting;

  /// Alias for [isSuccess].
  bool get hasValue => isSuccess;

  /// Returns the last known value.
  T? get lastValue => value.lastValue;

  /// Returns value if success, throws if error.
  ///
  /// Throws [StateError] if the operation is not yet complete or has no value.
  T get requireValue {
    final s = value;
    if (s is LxSuccess<T>) return s.value;
    if (s is LxError<T>) throw s.error;
    throw StateError('Async operation has no value yet (status: $s)');
  }

  /// Alias for [requireValue].
  T get computedValue => requireValue;

  /// Returns a future that completes when the operation succeeds or fails.
  ///
  /// If the current state is already success or error, returns immediately.
  /// Otherwise, waits for the next terminal state.
  Future<T> get wait async {
    final s = value;
    if (s is LxSuccess<T>) return Future.value(s.value);
    if (s is LxError<T>) return Future.error(s.error, s.stackTrace);

    var first = await stream.first;

    if (first is LxSuccess<T>) {
      return first.value;
    }

    if (first is LxError<T>) {
      throw first.error;
    }

    throw StateError('Async operation has no value yet (status: $s)');
  }

  /// Creates an [LxWatch] that listens to this async reactive value.
  ///
  /// This is a convenient shorthand for creating side effects that respond to
  /// async status changes. The callback receives the [LxStatus] and can
  /// use pattern matching to handle different states.
  ///
  /// Returns the created [LxWatch] which can be disposed manually or via
  /// [autoDispose] in a [LevitController].
  ///
  /// ## Usage
  /// ```dart
  /// final user = fetchUser().lx;
  ///
  /// // Listen to all status changes
  /// user.listen((status) {
  ///   status.when(
  ///     success: (data) => print('User: $data'),
  ///     error: (e, _) => print('Error: $e'),
  ///     waiting: () => print('Loading...'),
  ///   );
  /// });
  ///
  /// // Or use in a controller with auto-disposal
  /// class MyController extends LevitController {
  ///   final user = fetchUser().lx;
  ///
  ///   @override
  ///   void onInit() {
  ///     autoDispose(user.listen((status) {
  ///       // Handle status changes
  ///     }));
  ///   }
  /// }
  /// ```
  LxWatch<LxStatus<T>> listen(
    void Function(T value) onSuccess, {
    void Function()? onWaiting,
    void Function(Object)? onError,
    Function(Object error, StackTrace stackTrace)? onProcessingError,
  }) {
    return LxWatch.status(
      this,
      onWaiting: onWaiting,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
