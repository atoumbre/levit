import 'dart:async';

import 'async_status.dart';
import 'core.dart';

// ============================================================================
// LxStream<T>
// ============================================================================

/// A reactive wrapper for a [Stream].
///
/// [LxStream] listens to a stream and tracks its state using [LxStatus].
/// It uses lazy subscriptions: the source stream is subscribed to only when
/// the [LxStream] (or its [status]) has active listeners. When all listeners
/// unsubscribe, the source subscription is cancelled.
///
/// Use this class to treat a stream as a reactive variable that can be observed
/// in the UI.
/// in the UI.
/// A reactive wrapper for a [Stream].
class LxStream<T> extends _LxAsyncVal<T> {
  /// The bound stream (wrapped for lazy subscription).
  Stream<T>? _boundSourceStream;

  /// Creates an [LxStream] bound to the given [stream].
  LxStream(Stream<T> stream, {T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial),
            onListen: null, onCancel: null) {
    _bind(stream);
  }

  /// Creates an [LxStream] in an [LxIdle] state.
  LxStream.idle({T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial, idle: true),
            onListen: null, onCancel: null);

  void _bind(Stream<T> stream, {bool isInitial = true}) {
    final lastKnown = value.lastValue;

    // Update status to waiting when rebinding (not for initial constructor call with initial value)
    if (!isInitial) {
      setValueInternal(LxWaiting<T>(lastKnown));
    }

    // Capture status changes from the stream
    final statusStream = stream
        .transform<LxStatus<T>>(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              sink.add(LxSuccess<T>(data));
            },
            handleError: (error, stackTrace, sink) {
              sink.add(LxError<T>(error, stackTrace, value.lastValue));
            },
          ),
        )
        .asBroadcastStream(
          onCancel: (sub) => sub.cancel(),
        );

    // Bind this variable to progress/error updates
    bind(statusStream);

    // Provide the original stream as a lazy broadcast stream
    _boundSourceStream =
        this.stream.where((s) => s.hasValue).map((s) => s.valueOrNull as T);
  }

  // ---------------------------------------------------------------------------
  // Access (inherited from LxBase)
  // ---------------------------------------------------------------------------

  /// The current [LxStatus] of the stream.
  LxStatus<T> get status => value;

  /// The underlying value stream (unwrapped from status).
  Stream<T> get valueStream {
    if (_boundSourceStream == null) {
      throw StateError('No stream bound. Call bind() first.');
    }
    return _boundSourceStream!;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Binds to a new stream, replacing the current one.
  @override
  void bind(Stream<LxStatus<T>> stream) {
    super.bind(stream);
  }

  void bindStream(Stream<T> stream) {
    unbind();
    _bind(stream, isInitial: false);
  }

  /// Unbinds the current stream, stopping subscriptions.
  @override
  void unbind() {
    super.unbind();
    _boundSourceStream = null;
  }

  // ---------------------------------------------------------------------------
  // Listener API
  // ---------------------------------------------------------------------------

  /// Closes the [LxStream].
  ///
  /// This stops listening to the source stream and releases resources.
  @override
  void close() {
    unbind();
    super.close();
  }

  @override
  String toString() => 'LxStream($status)';

  // ---------------------------------------------------------------------------
  // Transformations
  // ---------------------------------------------------------------------------

  /// Transforms each element of this stream into a new stream event.
  LxStream<R> map<R>(R Function(T event) convert) {
    return LxStream<R>(valueStream.map(convert));
  }

  /// Creates a stream where each data event of this stream is asynchronously mapped
  /// to a new event.
  LxStream<E> asyncMap<E>(FutureOr<E> Function(T event) convert) {
    return LxStream<E>(valueStream.asyncMap(convert));
  }

  /// Transforms each element of this stream into a sequence of elements.
  LxStream<R> expand<R>(Iterable<R> Function(T element) convert) {
    return LxStream<R>(valueStream.expand(convert));
  }

  /// Filters events from this stream.
  LxStream<T> where(bool Function(T event) test) {
    return LxStream<T>(valueStream.where(test));
  }

  /// Skips data events if they are equal to the previous data event.
  LxStream<T> distinct([bool Function(T previous, T next)? equals]) {
    return LxStream<T>(valueStream.distinct(equals));
  }

  // ---------------------------------------------------------------------------
  // Reductions (returning LxFuture)
  // ---------------------------------------------------------------------------

  /// Combines a sequence of values by repeatedly applying [combine].
  LxFuture<T> reduce(T Function(T previous, T element) combine) {
    return LxFuture<T>(valueStream.reduce(combine));
  }

  /// Combines a sequence of values by repeatedly applying [combine], starting
  /// with an [initialValue].
  LxFuture<R> fold<R>(
      R initialValue, R Function(R previous, T element) combine) {
    return LxFuture<R>(valueStream.fold(initialValue, combine));
  }
}

// ============================================================================
// LxFuture<T>
// ============================================================================

/// A reactive wrapper for a [Future].
///
/// [LxFuture] executes a future and tracks its state using [LxStatus]
/// (Idle, Waiting, Success, Error). It uses lazy subscriptions: the future
/// is executed immediately, but status updates are only delivered when
/// there are active listeners.
///
/// Use this class to easily display the state of an asynchronous operation in
/// your UI (e.g., showing a loading spinner while fetching data).
/// your UI (e.g., showing a loading spinner while fetching data).
class LxFuture<T> extends _LxAsyncVal<T> {
  /// Creates an [LxFuture] that immediately executes the given [future].
  ///
  /// *   [future]: The future to execute and track.
  /// *   [initial]: An optional initial value. If provided, the status starts as
  ///     [LxSuccess] with this value while the future is loading (useful for
  ///     optimistic UI or cached data).
  LxFuture(Future<T> future, {T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial),
            onListen: null, onCancel: null) {
    _run(future);
  }

  /// Creates an [LxFuture] from a callback that returns a Future.
  ///
  /// This factory executes the callback immediately. It is useful when you want
  /// to defer the creation of the future until the [LxFuture] is instantiated.
  factory LxFuture.from(Future<T> Function() futureCallback, {T? initial}) {
    return LxFuture<T>(futureCallback(), initial: initial);
  }

  /// Creates an [LxFuture] in an [LxIdle] state.
  ///
  /// The future is not started until [refresh] is called.
  ///
  /// [initial] is an optional value to hold while idle.
  LxFuture.idle({T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial, idle: true),
            onListen: null, onCancel: null);

  /// The internal future currently being tracked.
  Future<T>? _activeFuture;

  void _run(Future<T> future, {bool isRefresh = false}) {
    _activeFuture = future;
    final lastKnown = value.lastValue;

    // Always set to waiting on refresh. For initial run, preserve initial success value.
    if (isRefresh || value is! LxSuccess<T>) {
      setValueInternal(LxWaiting<T>(lastKnown));
    }

    future.then((val) {
      // Only update if this future is still the active one (handle race conditions)
      if (_activeFuture == future) {
        setValueInternal(LxSuccess<T>(val));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (_activeFuture == future) {
        setValueInternal(LxError<T>(error, stackTrace, lastKnown));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Access
  // ---------------------------------------------------------------------------

  /// The current [LxStatus] of the future.
  ///
  /// Accessing this value from a reactive context (like [LWatch]) will
  /// automatically register this future as a dependency.
  LxStatus<T> get status => value;

  /// An alias for [status] required for the [LxReactive] interface.
  @override
  LxStatus<T> get value => super.value;

  /// A stream of status changes.
  ///
  /// The future execution itself is independent of this stream, but status
  /// updates are emitted here.
  @override
  Stream<LxStatus<T>> get stream => super.stream;

  /// Whether there are active subscribers to this future.
  @override
  bool get hasListener => super.hasListener;

  /// Returns a future that completes with the result.
  ///
  /// *   If an operation is currently in progress, returns the future of that operation.
  /// *   If successful, returns a future completing with the current value.
  /// *   If failed, returns a future completing with the error.
  /// *   If idle, throws a [StateError].
  Future<T> get wait {
    if (_activeFuture != null) return _activeFuture!;
    final s = status;
    if (s is LxSuccess<T>) return Future.value(s.value);
    if (s is LxError<T>) return Future.error(s.error, s.stackTrace);
    // LxIdle or LxWaiting without active future - both are idle-like states
    throw StateError(
        'LxFuture is idle. Call restart() to start execution or wait until it is not idle.');
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Refreshes the state with a new future.
  ///
  /// This sets the status to [LxWaiting] and tracks the new [future].
  ///
  /// Renamed from `refresh` to prevent conflict with [LxBase.refresh].
  void restart(Future<T> future) => _run(future, isRefresh: true);

  // ---------------------------------------------------------------------------
  // Listener API
  // ---------------------------------------------------------------------------

  /// Add a listener that will be called on every status change.
  @override
  void addListener(void Function() listener) {
    super.addListener(listener);
  }

  /// Remove a previously added listener.
  @override
  void removeListener(void Function() listener) {
    super.removeListener(listener);
  }

  /// Close and release resources.
  ///
  /// Call this when the [LxFuture] is no longer needed to free resources.
  @override
  void close() {
    super.close();
  }

  @override
  String toString() => 'LxFuture($status)';

  /// Converts this [LxFuture] into an [LxStream].
  ///
  /// The resulting stream will emit a single value (or error) when this future
  /// completes, and then close.
  LxStream<T> get asLxStream => LxStream<T>(wait.asStream());
}

// ============================================================================
// _LxAsyncVal<T>
// ============================================================================

/// Shared base class for asynchronous reactive values.
abstract class _LxAsyncVal<T> extends LxBase<LxStatus<T>> {
  _LxAsyncVal(LxStatus<T> initialValue,
      {required void Function()? onListen, required void Function()? onCancel})
      : super(initialValue, onListen: onListen, onCancel: onCancel);

  /// Helper to determine initial status.
  static LxStatus<T> initialStatus<T>(T? initial, {bool idle = false}) {
    if (initial != null) {
      return LxSuccess<T>(initial);
    }
    return idle ? LxIdle<T>() : LxWaiting<T>();
  }

  /// Transforms the stream of status events.
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<LxStatus<T>> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

// ============================================================================
// Extensions
// ============================================================================

/// Extension for creating [LxStream] from a [Stream].
extension LxStreamExtension<T> on Stream<T> {
  /// Wraps this stream in an [LxStream].
  LxStream<T> get lx => LxStream<T>(this);
}

/// Extension for creating [LxFuture] from a [Future].
extension LxFutureExtension<T> on Future<T> {
  /// Creates an [LxFuture] from this future.
  ///
  /// ```dart
  /// final user = fetchUser().lx;
  /// ```
  LxFuture<T> get lx => LxFuture<T>(this);
}
