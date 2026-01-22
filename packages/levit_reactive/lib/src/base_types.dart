import 'async_types.dart';
import 'core.dart';

// ============================================================================
// LxVar - Base Reactive Type that holds a mutable value
// ============================================================================

/// A reactive wrapper for a value of type [T].
///
/// [LxVar] is the core primitive of Levit's reactive system. It notifies
/// listeners whenever its value changes.
class LxVar<T> extends LxBase<T> {
  /// Creates a reactive wrapper around [initial].
  LxVar(super.initial, {super.onListen, super.onCancel, super.name});

  /// Sets the value and notifies listeners.
  set value(T val) => setValueInternal(val);

  /// Functional update override to support setting value.
  @override
  T call([T? v]) {
    if (v is T) {
      value = v;
    }
    return value;
  }

  LxStream<R> transform<R>(Stream<R> Function(Stream<T> stream) transformer) {
    return LxStream<R>(transformer(stream));
  }
}

// ============================================================================
// LxBool - Specialized reactive boolean
// ============================================================================

/// A reactive boolean with helper methods for common operations.
///
/// This specialized [Lx] type adds convenient methods like [toggle], [setTrue],
/// and [setFalse] to simplify boolean state management.
///
/// ## Usage
/// ```dart
/// final isVisible = LxBool(false);
/// isVisible.toggle();
/// ```
class LxBool extends LxVar<bool> {
  /// Creates a reactive boolean.
  ///
  /// [initial] defaults to `false`.
  LxBool([super.initial = false, String? name]) : super(name: name);

  /// Toggles the value between `true` and `false`.
  void toggle() => value = !value;

  /// Sets the value to `true`.
  void setTrue() => value = true;

  /// Sets the value to `false`.
  void setFalse() => value = false;

  /// Returns `true` if the value is `true`.
  bool get isTrue => value;

  /// Returns `true` if the value is `false`.
  bool get isFalse => !value;
}

// ============================================================================
// LxNum - Specialized reactive number
// ============================================================================

/// A reactive number with arithmetic helper methods.
///
/// This specialized [Lx] type adds methods like [increment], [decrement],
/// [add], and [multiply] for cleaner arithmetic operations on reactive state.
///
/// ## Usage
/// ```dart
/// final count = LxInt(0);
/// count.increment();
/// ```
class LxNum<T extends num> extends LxVar<T> {
  /// Creates a reactive number.
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

  /// Sets the value to the remainder of division by [other].
  void mod(num other) => value = (value % other) as T;

  /// Negates the value.
  void negate() => value = (-value) as T;

  /// Clamps the value between [min] and [max].
  void clampValue(T min, T max) {
    value = value.clamp(min, max) as T;
  }
}

/// A reactive integer.
typedef LxInt = LxNum<int>;

/// A reactive double.
typedef LxDouble = LxNum<double>;

// ============================================================================
// Extensions - The .lx syntax
// ============================================================================

/// Extensions to create reactive objects from standard types.
extension LxExtension<T> on T {
  /// Creates a reactive wrapper around this value.
  ///
  /// ```dart
  /// final count = 0.lx;
  /// final name = 'Levit'.lx;
  /// ```
  LxVar<T> get lx => LxVar<T>(this);

  /// Creates a nullable reactive wrapper around this value.
  LxVar<T?> get lxNullable => LxVar<T?>(this);
}

/// Extensions for boolean specific reactivity.
extension LxBoolExtension on bool {
  /// Creates a [LxBool] from this boolean.
  LxBool get lx => LxBool(this);
}

/// Extensions for integer specific reactivity.
extension LxIntExtension on int {
  /// Creates a [LxInt] from this integer.
  LxInt get lx => LxInt(this);
}

/// Extensions for double specific reactivity.
extension LxDoubleExtension on double {
  /// Creates a [LxDouble] from this double.
  LxDouble get lx => LxDouble(this);
}
