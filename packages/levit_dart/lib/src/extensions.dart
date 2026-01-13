part of '../levit_dart.dart';

// ---------------------------------------------------------------------------
// Put Extensions
// ---------------------------------------------------------------------------

/// Fluent API extensions for immediate dependency registration.
extension LevitPutExtension<T> on T {
  /// Registers this instance immediately in the active [LevitScope].
  ///
  /// This is a fluent alternative to `Levit.put(() => instance)`.
  /// Returns the registered instance.
  ///
  /// ```dart
  /// final service = MyService().levitPut();
  /// ```
  T levitPut() => Levit.put(() => this);
}

/// Fluent API extensions for lazy dependency registration on instances.
extension LevitLazyPutExtension<T> on T {
  /// Registers this instance as a lazy dependency in the active [LevitScope].
  ///
  /// The [builder] (which simply returns this instance) will only be called
  /// when the dependency is first requested.
  void levitLazyPut() => Levit.lazyPut(() => this);
}

/// Fluent API extensions for immediate registration using builder functions.
extension LevitPutBuilderExtension<T> on T Function() {
  /// Executes and registers the result of this builder in the active [LevitScope].
  ///
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the instance survives a non-forced reset.
  T levitPut({String? tag, bool permanent = false}) =>
      Levit.put<T>(this, tag: tag, permanent: permanent);
}

/// Fluent API extensions for lazy registration using builder functions.
extension LevitLazyPutBuilderExtension<T> on T Function() {
  /// Registers this builder for lazy instantiation in the active [LevitScope].
  ///
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration survives a non-forced reset.
  /// * [isFactory]: If `true`, the builder is executed for every `find` call.
  void levitLazyPut(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Levit.lazyPut<T>(this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Fluent API extensions for lazy asynchronous registration.
extension LevitLazyPutAsyncExtension<T> on Future<T> {
  /// Registers this [Future] as a lazy asynchronous dependency.
  ///
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration survives a non-forced reset.
  /// * [isFactory]: If `true`, the future is re-awaited for every `findAsync` call.
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Levit.lazyPutAsync(() => this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Fluent API extensions for lazy asynchronous registration using builders.
extension LevitLazyPutAsyncBuilderExtension<T> on Future<T> Function() {
  /// Registers this asynchronous builder for lazy instantiation.
  ///
  /// * [tag]: Optional unique identifier for the instance.
  /// * [permanent]: If `true`, the registration survives a non-forced reset.
  /// * [isFactory]: If `true`, the builder is re-run for every `findAsync` call.
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Levit.lazyPutAsync(this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}
