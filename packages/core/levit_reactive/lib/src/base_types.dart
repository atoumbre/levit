part of 'reactive_library.dart';

/// A reactive variable that holds a mutable value.
///
/// [LxVar] ("Levit Variable") is the primary primitive for mutable state.
/// It notifies active observers whenever its value changes.
///
/// ```dart
/// final count = LxVar(0);
///
/// // Update triggers notification
/// count.value++;
/// ```
///
/// Expose [asReadable] to publish an observation-only [LxReadable] view while
/// keeping mutations private inside a controller.
///
/// {@category Reactive State}
class LxVar<T> extends LxBase<T> implements LxAsyncResource {
  /// Creates a reactive variable with an [initial] value.
  LxVar(
    super.initial, {
    super.onListen,
    super.onCancel,
    super.name,
    super.isSensitive,
    super.equals,
  });

  /// Updates the value and triggers notifications if the value changed.
  set value(T val) => _setValueInternal(val);

  /// Reads the current value without modifying it, including nullable values.
  /// Use the [value] setter for writes.
  @override
  T call() => value;

  /// Applies an in-place [mutator] to the current value and notifies listeners
  /// via [refresh].
  void mutate(void Function(T value) mutator) {
    mutator(_value);
    refresh();
  }

  /// Replaces the current value with the result of [fn], reading the current
  /// value without registering a reactive dependency.
  void updateValue(T Function(T val) fn) => _setValueInternal(fn(_value));

  Stream<T>? _boundStream;
  StreamSubscription<T>? _boundSubscription;
  Set<Future<void>>? _bindingCancellations;
  List<AsyncError>? _bindingFailures;
  bool _bindingClosing = false;
  int _bindingGeneration = 0;

  /// Owns one upstream subscription until [unbind] or [close]. Subscribers use
  /// this value's stable stream, so replacing a binding preserves observation.
  void bind(Stream<T> externalStream) {
    if (isDisposed || _bindingClosing) {
      throw StateError('Cannot bind a closing value.');
    }
    if (identical(_boundStream, externalStream)) return;
    _cancelBinding();
    _boundStream = externalStream;
    final generation = _bindingGeneration;
    _boundSubscription = externalStream.listen(
      (event) {
        if (generation == _bindingGeneration && !isDisposed) {
          _setValueInternal(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (generation != _bindingGeneration || isDisposed) return;
        if (_controller?.hasListener ?? false) {
          _controller!.addError(error, stack);
        } else {
          Zone.current.handleUncaughtError(error, stack);
        }
      },
    );
  }

  void _cancelBinding() {
    _bindingGeneration++;
    _boundStream = null;
    final subscription = _boundSubscription;
    _boundSubscription = null;
    if (subscription == null) return;
    final cancellations = _bindingCancellations ??= {};
    late final Future<void> cancelled;
    cancelled = Future<void>.sync(subscription.cancel)
        .catchError((Object error, StackTrace stack) {
          (_bindingFailures ??= []).add(AsyncError(error, stack));
        })
        .whenComplete(() => cancellations.remove(cancelled));
    cancellations.add(cancelled);
  }

  /// Detaches immediately and waits for all replaced upstream subscriptions.
  Future<void> unbind() {
    _cancelBinding();
    return drain();
  }

  @override
  void requestCancel() {
    _bindingClosing = true;
    _cancelBinding();
  }

  bool get _isDrainedSync {
    final cancellations = _bindingCancellations;
    final failures = _bindingFailures;
    return (cancellations == null || cancellations.isEmpty) &&
        (failures == null || failures.isEmpty);
  }

  @override
  Future<void> drain() {
    if (_isDrainedSync) return Future<void>.value();
    return _drainAsync();
  }

  Future<void> _drainAsync() async {
    final cancellations = _bindingCancellations;
    if (cancellations != null) {
      while (cancellations.isNotEmpty) {
        await Future.wait(cancellations.toList());
      }
    }
    final failures = _bindingFailures;
    if (failures != null && failures.isNotEmpty) {
      throw LxCleanupException(failures);
    }
  }

  @override
  FutureOr<void> _cleanupBinding() {
    requestCancel();
    if (_bindingCancellations == null && _bindingFailures == null) {
      return null;
    }
    return drain();
  }

  /// Transforms the stream of changes using [transformer].
  ///
  /// Returns a new [LxStream] reflecting the transformed data.
  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

/// A reactive boolean variable (`LxVar<bool>`).
///
/// Semantic helpers (`toggle`, `setTrue`, `setFalse`, `isTrue`, `isFalse`) are
/// available on every [LxBool] via [LxBoolOperations].
///
/// {@category Reactive State}
typedef LxBool = LxVar<bool>;

/// A reactive integer variable (`LxVar<int>`).
///
/// Arithmetic helpers (`increment`, `decrement`, `add`, `subtract`,
/// `multiply`, `divide`, `mod`, `negate`, `clampValue`) are available on every
/// [LxInt] via [LxIntOperations].
///
/// {@category Reactive State}
typedef LxInt = LxVar<int>;

/// A reactive double variable (`LxVar<double>`).
///
/// Arithmetic helpers (`add`, `subtract`, `multiply`, `divide`, `mod`,
/// `negate`, `clampValue`) are available on every [LxDouble] via
/// [LxDoubleOperations].
///
/// {@category Reactive State}
typedef LxDouble = LxVar<double>;

/// Semantic boolean helpers for [LxBool] (`LxVar<bool>`).
///
/// {@category Reactive State}
extension LxBoolOperations on LxVar<bool> {
  /// Toggles the current value.
  void toggle() => value = !value;

  /// Explicitly sets the value to `true`.
  void setTrue() => value = true;

  /// Explicitly sets the value to `false`.
  void setFalse() => value = false;

  /// Returns `true` if the current value is `true`.
  bool get isTrue => value;

  /// Returns `true` if the current value is `false`.
  bool get isFalse => !value;
}

/// Arithmetic helpers for [LxInt] (`LxVar<int>`).
///
/// {@category Reactive State}
extension LxIntOperations on LxVar<int> {
  /// Increments the value by 1.
  void increment() => value = value + 1;

  /// Decrements the value by 1.
  void decrement() => value = value - 1;

  /// Adds [other] to the current value.
  void add(int other) => value = value + other;

  /// Subtracts [other] from the current value.
  void subtract(int other) => value = value - other;

  /// Multiplies the current value by [other].
  void multiply(int other) => value = value * other;

  /// Performs integer division by [other].
  void divide(int other) {
    if (other == 0) throw ArgumentError('Cannot divide by zero');
    value = value ~/ other;
  }

  /// Assigns the result of `value % other` to the variable.
  void mod(int other) => value = value % other;

  /// Negates the current value.
  void negate() => value = -value;

  /// Clamps the value between [min] and [max].
  void clampValue(int min, int max) {
    value = value.clamp(min, max);
  }
}

/// Arithmetic helpers for [LxDouble] (`LxVar<double>`).
///
/// {@category Reactive State}
extension LxDoubleOperations on LxVar<double> {
  /// Adds [other] to the current value.
  void add(num other) => value = value + other;

  /// Subtracts [other] from the current value.
  void subtract(num other) => value = value - other;

  /// Multiplies the current value by [other].
  void multiply(num other) => value = value * other;

  /// Divides the current value by [other].
  void divide(num other) {
    if (other == 0) throw ArgumentError('Cannot divide by zero');
    value = value / other;
  }

  /// Assigns the result of `value % other` to the variable.
  void mod(num other) => value = value % other;

  /// Negates the current value.
  void negate() => value = -value;

  /// Clamps the value between [min] and [max].
  void clampValue(double min, double max) {
    value = value.clamp(min, max);
  }
}

/// Extensions to create reactive variables from any Dart value.
///
/// {@category Reactive State}
extension LxExtension<T> on T {
  /// Creates an [LxVar] holding this value.
  ///
  /// ```dart
  /// final name = 'Levit'.lx;
  /// ```
  LxVar<T> get lx => LxVar<T>(this);

  /// Wraps this value in a reactive [LxVar] with optional configuration.
  LxVar<T> lxVar({String? name, bool isSensitive = false}) =>
      LxVar<T>(this, name: name, isSensitive: isSensitive);

  /// Wraps this value in a nullable reactive [LxVar].
  LxVar<T?> get lxNullable => LxVar<T?>(this);
}
