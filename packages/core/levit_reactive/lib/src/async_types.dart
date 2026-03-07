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
/// // Example usage:
/// ```dart
/// final counter = Stream.periodic(Duration(seconds: 1), (i) => i).lx;
///
/// // UI automatically rebuilds on new events
/// LWatch(() => Text('${counter.value.data}'));
/// ```
class LxStream<T> extends _LxAsyncVal<T> {
  StreamController<T>? _valueController;
  StreamSubscription<T>? _activeSubscription;
  Stream<T> Function()? _streamFactory;
  bool _hasBoundSource = false;
  int _bindEpoch = 0;

  /// Creates an [LxStream] bound to the given [stream].
  /// Note: If the stream is a single-subscription stream, it cannot be safely re-listened to
  /// after losing all subscribers. Prefer using [LxStream.defer] for single-subscription streams.
  factory LxStream(Stream<T> stream, {T? initial}) {
    return LxStream<T>._internal(
      _LxAsyncVal.initialStatus<T>(initial),
      () => stream,
    );
  }

  /// Creates an [LxStream] that lazily generates its underlying stream using [factory]
  /// whenever it becomes active. This is strictly required for safely recreating
  /// single-subscription operations like `.map` when an [LxStream] re-activates.
  factory LxStream.defer(Stream<T> Function() factory, {T? initial}) {
    return LxStream<T>._internal(
      _LxAsyncVal.initialStatus<T>(initial),
      factory,
    );
  }

  /// Creates an [LxStream] in an [LxIdle] state.
  factory LxStream.idle({T? initial}) {
    return LxStream<T>._internal(
      _LxAsyncVal.initialStatus<T>(initial, idle: true),
      null,
    );
  }

  LxStream._internal(LxStatus<T> initialStatus, Stream<T> Function()? factory)
      : super(initialStatus, onListen: () {}, onCancel: () {}) {
    if (factory != null) {
      _assignFactory(factory);
    }
  }

  @override
  void _protectedOnActive() {
    super._protectedOnActive();
    _checkPendingBind();
  }

  @override
  void _protectedOnInactive() {
    super._protectedOnInactive();
    _cleanup();
  }

  void _assignFactory(Stream<T> Function() factory) {
    _streamFactory = factory;
    _hasBoundSource = true;
  }

  void _checkPendingBind() {
    if (_streamFactory != null && _activeSubscription == null) {
      _bind(_streamFactory!());
    }
  }

  void _bind(Stream<T> stream) {
    final epoch = ++_bindEpoch;

    _activeSubscription?.cancel();
    _activeSubscription = stream.listen(
      (data) {
        if (_bindEpoch != epoch || isDisposed) return;
        _setValueInternal(LxSuccess<T>(data));
        _valueController?.add(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_bindEpoch != epoch || isDisposed) return;
        _setValueInternal(LxError<T>(error, stackTrace, _value.lastValue));
      },
      onDone: () {
        if (_bindEpoch != epoch || isDisposed) return;
        close();
      },
    );
  }

  /// Returns the current [LxStatus] of the stream.
  LxStatus<T> get status => value;

  /// Returns the raw stream of values, unwrapped from [LxStatus].
  Stream<T> get valueStream {
    if (!_hasBoundSource) {
      throw StateError('No source stream bound or stream has been closed.');
    }
    _valueController ??= StreamController<T>.broadcast(
      onListen: () {
        _checkActive();
        _checkPendingBind();
      },
      onCancel: _checkActive,
    );
    _checkPendingBind();
    return _valueController!.stream;
  }

  @override
  bool get hasListener =>
      super.hasListener || (_valueController?.hasListener ?? false);

  /// Re-executes the stream operation with a new [stream].
  /// This binds to a static stream instance. See [restartDeferred] for single-subscription streams.
  void restart(Stream<T> stream) {
    restartDeferred(() => stream);
  }

  /// Re-executes the stream operation and registers a new [factory] for future re-activations.
  void restartDeferred(Stream<T> Function() factory) {
    _cleanup();
    _assignFactory(factory);
    _setValueInternal(LxWaiting<T>(_value.lastValue));

    // If already active, immediately start bound stream.
    if (hasListener) {
      _checkPendingBind();
    }
  }

  void _cleanup() {
    _bindEpoch++;
    _activeSubscription?.cancel();
    _activeSubscription = null;
  }

  @override
  void close() {
    _cleanup();
    _streamFactory = null;
    _hasBoundSource = false;
    _valueController?.close();
    _valueController = null;
    super.close();
  }

  @override
  String toString() => 'LxStream($status)';

  /// Transforms each data event with [convert].
  LxStream<R> map<R>(R Function(T event) convert) {
    return LxStream<R>.defer(() => valueStream.map(convert));
  }

  /// Asynchronously transforms each data event.
  LxStream<E> asyncMap<E>(FutureOr<E> Function(T event) convert) {
    return LxStream<E>.defer(() => valueStream.asyncMap(convert));
  }

  /// Expands each event into an iterable of events.
  LxStream<R> expand<R>(Iterable<R> Function(T element) convert) {
    return LxStream<R>.defer(() => valueStream.expand(convert));
  }

  /// Filters events based on [test].
  LxStream<T> where(bool Function(T event) test) {
    return LxStream<T>.defer(() => valueStream.where(test));
  }

  /// Skips duplicate events.
  LxStream<T> distinct([bool Function(T previous, T next)? equals]) {
    return LxStream<T>.defer(() => valueStream.distinct(equals));
  }

  /// Reduces the stream to a single value using [combine].
  LxFuture<T> reduce(T Function(T previous, T element) combine) {
    return LxFuture<T>.from(() => valueStream.reduce(combine));
  }

  /// Folds the stream into a single [LxFuture] result.
  LxFuture<R> fold<R>(
      R initialValue, R Function(R previous, T element) combine) {
    return LxFuture<R>.from(() => valueStream.fold(initialValue, combine));
  }
}

/// A reactive wrapper for a [Future].
///
/// [LxFuture] tracks the execution state ([LxStatus]) of an asynchronous operation.
/// It creates a synchronous access point for the Future's current status (idle, waiting, success, error).
///
/// // Example usage:
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
    final lastKnown = _value.lastValue;

    if (isRefresh || _value is! LxSuccess<T>) {
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
    return LxStream<R>.defer(() => transformer(stream));
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
