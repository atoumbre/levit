part of '../levit_scope.dart';

/// Extensions for registering instances directly into the active [LevitScope].
extension LevitInstanceExtension<T> on T {
  /// Registers this instance in the active [LevitScope].
  ///
  /// This is a fluent shortcut for [Ls.put].
  ///
  /// Example:
  /// ```dart
  /// final service = MyService().levitPut();
  /// ```
  ///
  /// Returns the registered instance.
  T levitPut() => Ls.put(() => this);

  /// Registers this instance as a lazy singleton in the active [LevitScope].
  ///
  /// The instance is only retrieved when first requested via [Ls.find].
  void levitLazyPut() => Ls.lazyPut(() => this);
}

/// Extensions for registering builder functions.
extension LevitBuilderExtension<T> on T Function() {
  /// Registers the result of this builder in the active [LevitScope].
  ///
  /// Use [tag] to distinguish between multiple instances of the same type.
  /// Set [permanent] to `true` to persist across resets.
  ///
  /// Returns the created instance.
  T levitPut({String? tag, bool permanent = false}) =>
      Ls.put<T>(this, tag: tag, permanent: permanent);

  /// Registers this builder for lazy instantiation in the active [LevitScope].
  ///
  /// The builder will only be executed when the dependency is first requested.
  ///
  /// If [isFactory] is `true`, the builder runs for every request.
  void levitLazyPut(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPut<T>(this, tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Extensions for registering asynchronous dependencies.
extension LevitAsyncInstanceExtension<T> on Future<T> {
  /// Registers this [Future] as a lazy asynchronous dependency.
  ///
  /// Use [tag] to differentiate instances.
  /// Set [isFactory] to `true` to re-await the future on every [Ls.findAsync].
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPutAsync(() => this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}

/// Extensions for registering asynchronous builder functions.
extension LevitAsyncBuilderExtension<T> on Future<T> Function() {
  /// Registers this asynchronous builder for lazy instantiation.
  ///
  /// The builder runs when [Ls.findAsync] is called.
  ///
  /// If [isFactory] is `true`, the builder runs for every request.
  void levitLazyPutAsync(
          {String? tag, bool permanent = false, bool isFactory = false}) =>
      Ls.lazyPutAsync(this,
          tag: tag, permanent: permanent, isFactory: isFactory);
}
