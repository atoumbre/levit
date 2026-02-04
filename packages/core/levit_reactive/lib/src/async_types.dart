part of '../levit_reactive.dart';

/// A reactive wrapper for a [Stream].
///
/// [LxStream] tracks the latest state ([LxStatus]) of a source stream and
/// supports lazy subscription. The underlying stream is only listened to when
/// the [LxStream] itself has active observers or listeners.
///
/// Key Features:
/// *   **Status Tracking**: Automatically emits [LxSuccess], [LxError], or [LxWaiting].
/// *   **Lazy Subscription**: Minimizes resource usage by pausing the source when unused.
/// *   **Rx Operations**: Includes [map], [where], [expand] (etc.) that return new [LxStream]s.
///
/// Example:
/// ```dart
/// final counter = Stream.periodic(Duration(seconds: 1), (i) => i).lx;
///
/// // UI automatically rebuilds on new events
/// LWatch(() => Text('${counter.value.data}'));
/// ```
class LxStream<T> extends _LxAsyncVal<T> {
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

    if (!isInitial) {
      _setValueInternal(LxWaiting<T>(lastKnown));
    }

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

    bind(statusStream);

    _boundSourceStream =
        this.stream.where((s) => s.hasValue).map((s) => s.valueOrNull as T);
  }

  /// Returns the current [LxStatus] of the stream.
  LxStatus<T> get status => value;

  /// Returns the raw stream of values, unwrapped from [LxStatus].
  Stream<T> get valueStream {
    if (_boundSourceStream == null) {
      throw StateError('No source stream bound or stream has been closed.');
    }
    return _boundSourceStream!;
  }

  @override
  void bind(Stream<LxStatus<T>> stream) => super.bind(stream);

  /// Replace the current source stream with a new one.
  void bindStream(Stream<T> stream) {
    unbind();
    _bind(stream, isInitial: false);
  }

  @override
  void unbind() {
    super.unbind();
    _boundSourceStream = null;
  }

  @override
  void close() {
    unbind();
    super.close();
  }

  @override
  String toString() => 'LxStream($status)';

  /// Transforms each data event with [convert].
  LxStream<R> map<R>(R Function(T event) convert) {
    return LxStream<R>(valueStream.map(convert));
  }

  /// Asynchronously transforms each data event.
  LxStream<E> asyncMap<E>(FutureOr<E> Function(T event) convert) {
    return LxStream<E>(valueStream.asyncMap(convert));
  }

  /// Expands each event into an iterable of events.
  LxStream<R> expand<R>(Iterable<R> Function(T element) convert) {
    return LxStream<R>(valueStream.expand(convert));
  }

  /// Filters events based on [test].
  LxStream<T> where(bool Function(T event) test) {
    return LxStream<T>(valueStream.where(test));
  }

  /// Skips duplicate events.
  LxStream<T> distinct([bool Function(T previous, T next)? equals]) {
    return LxStream<T>(valueStream.distinct(equals));
  }

  /// Reduces the stream to a single value using [combine].
  LxFuture<T> reduce(T Function(T previous, T element) combine) {
    return LxFuture<T>(valueStream.reduce(combine));
  }

  /// Folds the stream into a single [LxFuture] result.
  LxFuture<R> fold<R>(
      R initialValue, R Function(R previous, T element) combine) {
    return LxFuture<R>(valueStream.fold(initialValue, combine));
  }
}

/// A reactive wrapper for a [Future].
///
/// [LxFuture] tracks the execution state ([LxStatus]) of an asynchronous operation.
/// It creates a synchronous access point for the Future's current status (idle, waiting, success, error).
///
/// Example:
/// ```dart
/// final user = fetchUser().lx;
///
/// LWatch(() {
///   return switch (user.status) {
///     LxWaiting() => CircularProgressIndicator(),
///     LxError(error: var e) => Text('Error: $e'),
///     LxSuccess(data: var u) => UserProfile(u),
///     _ => SizedBox(),
///   };
/// });
/// ```
class LxFuture<T> extends _LxAsyncVal<T> {
  /// Executes [future] immediately and tracks its status.
  LxFuture(Future<T> future, {T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial),
            onListen: null, onCancel: null) {
    _run(future);
  }

  /// Convenience factory to create an [LxFuture] from a closure.
  factory LxFuture.from(Future<T> Function() futureCallback, {T? initial}) {
    return LxFuture<T>(futureCallback(), initial: initial);
  }

  /// Creates an [LxFuture] in an [LxIdle] state.
  LxFuture.idle({T? initial})
      : super(_LxAsyncVal.initialStatus<T>(initial, idle: true),
            onListen: null, onCancel: null);

  Future<T>? _activeFuture;

  void _run(Future<T> future, {bool isRefresh = false}) {
    _activeFuture = future;
    final lastKnown = value.lastValue;

    if (isRefresh || value is! LxSuccess<T>) {
      _setValueInternal(LxWaiting<T>(lastKnown));
    }

    future.then((val) {
      if (_activeFuture == future && !isDisposed) {
        _setValueInternal(LxSuccess<T>(val));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (_activeFuture == future && !isDisposed) {
        _setValueInternal(LxError<T>(error, stackTrace, lastKnown));
      }
    });
  }

  /// Returns the current [LxStatus] of the operation.
  LxStatus<T> get status => value;

  /// Returns a Future that completes when the operation succeeds or fails.
  ///
  /// Throws [StateError] if the future is currently [LxIdle].
  Future<T> get wait {
    if (_activeFuture != null) return _activeFuture!;
    final s = status;
    if (s is LxSuccess<T>) return Future.value(s.value);
    if (s is LxError<T>) return Future.error(s.error, s.stackTrace);
    throw StateError('LxFuture is idle. Call restart() to begin execution.');
  }

  /// Re-executes the operation with a new [future].
  void restart(Future<T> future) => _run(future, isRefresh: true);

  @override
  String toString() => 'LxFuture($status)';

  /// Returns an [LxStream] representation of this future.
  LxStream<T> get asLxStream => LxStream<T>(wait.asStream());
}

/// Internal base class for async reactive values.
abstract class _LxAsyncVal<T> extends LxBase<LxStatus<T>> {
  _LxAsyncVal(LxStatus<T> initialValue,
      {required void Function()? onListen, required void Function()? onCancel})
      : super(initialValue, onListen: onListen, onCancel: onCancel);

  static LxStatus<T> initialStatus<T>(T? initial, {bool idle = false}) {
    if (initial != null) return LxSuccess<T>(initial);
    return idle ? LxIdle<T>() : LxWaiting<T>();
  }

  /// Transforms the status sequence into a new [LxStream].
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<LxStatus<T>> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

/// Extensions for converting [Stream]s to [LxStream]s.
extension LxStreamExtension<T> on Stream<T> {
  /// Converts this [Stream] into a reactive [LxStream].
  LxStream<T> get lx => LxStream<T>(this);
}

/// Extensions for converting [Future]s to [LxFuture]s.
extension LxFutureExtension<T> on Future<T> {
  /// Converts this [Future] into a reactive [LxFuture].
  LxFuture<T> get lx => LxFuture<T>(this);
}
