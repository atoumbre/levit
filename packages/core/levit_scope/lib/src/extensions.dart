part of '../levit_scope.dart';

/// Fluent API extensions for immediate dependency instance registration.
extension LevitInstanceExtension<T> on T {
  /// Registers this instance immediately in the active [LevitScope].
  ///
  /// This is a fluent alternative to [Ls.put].
  ///
  /// // Example usage:
  /// ```dart
  /// final service = MyService().levitPut();
  /// ```
  ///
  /// Returns the registered instance.
  T levitPut() => Ls.put(() => this);

  /// Registers this instance as a lazy dependency in the active [LevitScope].
  ///
  /// The instance will only be resolved when first requested via [Ls.find].
  void levitLazyPut() => Ls.lazyPut(() => this);
}

/// Fluent API extensions for immediate registration using builder functions.
extension LevitBuilderExtension<T> on T Function() {
  /// Executes and registers the result of this builder in the active [LevitScope].
  ///
  /// Parameters:
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the instance survives a non-forced reset.
  ///
  /// Returns the created instance.
  T levitPut({String? tag, bool permanent = false}) =>
      Ls.put<T>(this, tag: tag, permanent: permanent);

  /// Registers this builder for lazy instantiation in the active [LevitScope].
  ///
  /// Parameters:
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the registration survives a non-forced reset.
  /// - [isFactory]: If `true`, the builder is executed for every `find` call.
  void levitLazyPut(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPut<T>(this, tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Fluent API extensions for lazy asynchronous registration.
extension LevitAsyncInstanceExtension<T> on Future<T> {
  /// Registers this [Future] as a lazy asynchronous dependency.
  ///
  /// Parameters:
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the registration survives a non-forced reset.
  /// - [isFactory]: If `true`, the future is re-awaited for every `findAsync` call.
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPutAsync(() => this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Fluent API extensions for lazy asynchronous registration using builders.
extension LevitAsyncBuilderExtension<T> on Future<T> Function() {
  /// Registers this asynchronous builder for lazy instantiation.
  ///
  /// Parameters:
  /// - [tag]: Optional unique identifier for the instance.
  /// - [permanent]: If `true`, the registration survives a non-forced reset.
  /// - [isFactory]: If `true`, the builder is re-run for every `findAsync` call.
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPutAsync(this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}
