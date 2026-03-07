part of '../levit_reactive.dart';

/// A reactive variable that holds a mutable value.
///
/// [LxVar] ("Levit Variable") is the primary primitive for mutable state.
/// It notifies active observers whenever its value changes.
///
/// // Example usage:
/// ```dart
/// final count = LxVar(0);
///
/// // Update triggers notification
/// count.value++;
/// ```
class LxVar<T> extends LxBase<T> with _LxMutable<T> {
  /// Creates a reactive variable with an [initial] value.
  LxVar(super.initial,
      {super.onListen,
      super.onCancel,
      super.name,
      super.isSensitive,
      super.equals});

  /// Updates the value and triggers notifications if the value changed.
  set value(T val) => _setValueInternal(val);

  /// Updates and retrieves the value using call syntax.
  ///
  /// If called with an argument, it updates the value.
  /// If called without arguments, it returns the current value.
  ///
  /// // Example usage:
  /// ```dart
  /// count(5); // Update
  /// print(count()); // Read
  /// ```
  @override
  T call([T? v]) {
    if (v is T) {
      value = v;
    }
    return value;
  }

  /// Transforms the stream of changes using [transformer].
  ///
  /// Returns a new [LxStream] reflecting the transformed data.
  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

/// A reactive state container for immutable data flow.
///
/// [LxState] is similar to [LxVar], but enforces explicit state transitions
/// via [emit] or [update] instead of property setters.
///
/// It is ideal for managing complex state objects where you want to ensure
/// controlled modification.
///
/// Unlike [LxVar], it does not expose in-place mutation helpers or stream
/// binding APIs.
class LxState<T> extends LxBase<T> {
  /// Creates a state container with an [initial] value.
  LxState(super.initial,
      {super.onListen,
      super.onCancel,
      super.name,
      super.isSensitive,
      super.equals});

  /// Emits a new [state].
  ///
  /// This triggers a notification to all listeners if the [state] is different
  /// from the current value.
  @protected
  void emit(T state) => _setValueInternal(state);

  /// Updates the state by applying a [reducer] function to the current value.
  ///
  /// // Example usage:
  /// ```dart
  /// state.update((s) => s.copyWith(count: s.count + 1));
  /// ```
  void update(T Function(T state) reducer) {
    _setValueInternal(reducer(value));
  }

  /// Exposes this state as a read-only [LxReactive] interface.
  ///
  /// Useful for exposing public API from a controller while keeping the
  /// mutation logic private.
  LxReactive<T> get asReactive => this;
}

/// A reactive boolean with specialized toggling methods.
///
/// [LxBool] provides semantic helpers like [toggle], [setTrue], and [setFalse].
class LxBool extends LxVar<bool> {
  /// Creates a reactive boolean. [initial] defaults to `false`.
  LxBool([super.initial = false, String? name, bool isSensitive = false])
      : super(name: name, isSensitive: isSensitive);

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

/// A reactive integer with arithmetic extensions.
///
/// Unboxed for maximum performance compared to a generic number container.
class LxInt extends LxVar<int> {
  /// Creates a reactive integer instance.
  LxInt(super.initial, {super.name, super.isSensitive});

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

/// A reactive double with arithmetic extensions.
///
/// Unboxed for maximum performance compared to a generic number container.
class LxDouble extends LxVar<double> {
  /// Creates a reactive double instance.
  LxDouble(super.initial, {super.name, super.isSensitive});

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

/// Extensions to create reactive variables from primitive values.
extension LxExtension<T> on T {
  /// Creates an [LxVar] holding this value.
  ///
  /// // Example usage:
  /// ```dart
  /// final name = 'Levit'.lx;
  /// ```
  LxVar<T> get lx => LxVar<T>(this);

  /// Wraps this value in a reactive [LxVar] with optional configuration.
  LxVar<T> lxVar({String? named, bool isSensitive = false}) =>
      LxVar<T>(this, name: named, isSensitive: isSensitive);

  /// Wraps this value in a nullable reactive [LxVar].
  LxVar<T?> get lxNullable => LxVar<T?>(this);
}

/// Specialized `.lx` extension for booleans.
extension LxBoolExtension on bool {
  /// Creates an [LxBool] from this value.
  LxBool get lx => LxBool(this);
}

/// Specialized `.lx` extension for integers.
extension LxIntExtension on int {
  /// Creates an [LxInt] from this value.
  LxInt get lx => LxInt(this);
}

/// Specialized extensions for [double].
extension LxDoubleExtension on double {
  /// Creates an [LxDouble] from this value.
  LxDouble get lx => LxDouble(this);
}
