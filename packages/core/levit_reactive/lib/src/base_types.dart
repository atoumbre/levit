part of '../levit_reactive.dart';

/// A reactive variable that holds a mutable value.
///
/// [LxVar] is the primary way to define piece of mutable state in the Levit
/// ecosystem. It extends [LxBase] to provide a public setter for [value]
/// and additional fluent utilities.
///
/// ### Usage
/// ```dart
/// final count = LxVar(0);
/// count.value++; // Updates and notifies
/// ```
class LxVar<T> extends LxBase<T> {
  /// Creates a reactive variable with an [initial] value.
  LxVar(super.initial, {super.onListen, super.onCancel, super.name});

  /// Updates the value and triggers notifications if the value changed.
  set value(T val) => setValueInternal(val);

  /// Functional-style update and retrieval.
  ///
  /// // Example:
  /// ```dart
  /// count(5); // sets value to 5
  /// print(count()); // returns 5
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

/// A reactive boolean with specialized state manipulation methods.
///
/// [LxBool] simplifies common boolean operations like toggling and explicit
/// true/false assignment.
class LxBool extends LxVar<bool> {
  /// Creates a reactive boolean. [initial] defaults to `false`.
  LxBool([super.initial = false, String? name]) : super(name: name);

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

/// A reactive number with fluent arithmetic extensions.
class LxNum<T extends num> extends LxVar<T> {
  /// Creates a reactive number instance.
  LxNum(super.initial, {super.name});

  /// Increments the value by 1.
  void increment() => value = (value + 1) as T;

  /// Decrements the value by 1.
  void decrement() => value = (value - 1) as T;

  /// Adds [other] to the current value.
  void add(num other) => value = (value + other) as T;

  /// Subtracts [other] from the current value.
  void subtract(num other) => value = (value - other) as T;

  /// Multiplies the current value by [other].
  void multiply(num other) => value = (value * other) as T;

  /// Divides the current value by [other].
  void divide(num other) => value = (value / other) as T;

  /// Performs integer division by [other].
  void intDivide(num other) => value = (value ~/ other) as T;

  /// Assigns the result of `value % other` to the variable.
  void mod(num other) => value = (value % other) as T;

  /// Negates the current value.
  void negate() => value = (-value) as T;

  /// Clamps the value between [min] and [max].
  void clampValue(T min, T max) {
    value = value.clamp(min, max) as T;
  }
}

/// Type alias for a reactive integer.
typedef LxInt = LxNum<int>;

/// Type alias for a reactive double.
typedef LxDouble = LxNum<double>;

/// Extensions to provide the signature `.lx` syntax for creating reactive state.
extension LxExtension<T> on T {
  /// Wraps this value in a reactive [LxVar].
  ///
  /// ```dart
  /// final name = 'Levit'.lx;
  /// ```
  LxVar<T> get lx => LxVar<T>(this);

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

/// Specialized `.lx` extension for doubles.
extension LxDoubleExtension on double {
  /// Creates an [LxDouble] from this value.
  LxDouble get lx => LxDouble(this);
}
