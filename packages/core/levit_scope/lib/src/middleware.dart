part of 'scope_library.dart';

/// Interface for observing and intercepting [LevitScope] lifecycle events.
///
/// Implement this interface to create middleware for logging, profiling, or
/// custom lifecycle management.
///
/// {@category Middleware & Monitoring}
abstract class LevitScopeMiddleware {
  /// Creates a [LevitScopeMiddleware].
  const LevitScopeMiddleware();

  /// Called when a new [LevitScope] is created.
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {}

  /// Called when a [LevitScope] is disposed.
  /// Failures are aggregated after every disposal observer has been attempted.
  void onScopeDispose(int scopeId, String scopeName) {}

  /// Called when a dependency or alias is registered in a scope.
  ///
  /// This triggers on [LevitScope.put], [LevitScope.lazyPut],
  /// [LevitScope.lazyPutAsync], and [LevitScope.bindExisting].
  void onDependencyRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {}

  /// Called when a dependency resolution instantiates a lazy or factory
  /// registration, or resolves an uncached alias.
  ///
  /// Already-instantiated singletons returned from the scope's instance cache
  /// do not invoke this callback on subsequent reads.
  void onDependencyResolve(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {}

  /// Called when a dependency is removed.
  ///
  /// This triggers on [LevitScope.delete], [LevitScope.reset] or scope disposal.
  /// A failure does not prevent other deletion observers or resource cleanup;
  /// the awaited operation reports all failures after cleanup finishes.
  void onDependencyDelete(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {}

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
  ) => builder;

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
  ) => onInit;
}
