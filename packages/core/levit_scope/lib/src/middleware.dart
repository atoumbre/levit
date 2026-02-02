part of '../levit_scope.dart';

/// Interface for observing and intercepting [LevitScope] lifecycle events.
///
/// Implement this interface to create middleware for logging, profiling, or
/// custom lifecycle management.
abstract class LevitScopeMiddleware {
  /// Creates a [LevitScopeMiddleware].
  const LevitScopeMiddleware();

  /// Called when a new [LevitScope] is created.
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {}

  /// Called when a [LevitScope] is disposed.
  void onScopeDispose(int scopeId, String scopeName) {}

  /// Called when a dependency matches a registration request.
  ///
  /// This triggers on [LevitScope.put], [LevitScope.lazyPut], and their variants.
  void onDependencyRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Called when a dependency instance is resolved.
  ///
  /// This triggers when [LevitScope.find] or its variants successfully return an instance.
  void onDependencyResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Called when a dependency is removed.
  ///
  /// This triggers on [LevitScope.delete] or [LevitScope.reset].
  void onDependencyDelete(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Intercepts the instantiation logic of a dependency.
  ///
  /// Override this to wrap the [builder], enabling custom behavior like executing
  /// within a specific [Zone].
  ///
  /// Returns the functional wrapper around [builder].
  S Function() onDependencyCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) =>
      builder;

  /// Intercepts the [onInit] call of a dependency.
  ///
  /// Override this to wrap execution of [onInit], for example to auto-capture
  /// reactive objects created during initialization.
  ///
  /// Returns the functional wrapper around [onInit].
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) =>
      onInit;
}
