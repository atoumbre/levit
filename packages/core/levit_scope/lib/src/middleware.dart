part of '../levit_scope.dart';

/// Interface for middleware hooks on dependency injection events.
///
/// Implement this interface to receive callbacks when dependencies are
/// registered, resolved, or deleted across any [LevitScope].
abstract class LevitScopeMiddleware {
  /// Base constructor.
  const LevitScopeMiddleware();

  /// Called when a new scope is created.
  ///
  /// *   [scopeId]: Unique identifier for the new scope.
  /// *   [scopeName]: The name of the new scope.
  /// *   [parentScopeId]: The ID of the parent scope, or null if root.
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {}

  /// Called when a scope is disposed.
  ///
  /// *   [scopeId]: The unique identifier of the disposed scope.
  /// *   [scopeName]: The name of the disposed scope.
  void onScopeDispose(int scopeId, String scopeName) {}

  /// Called when a dependency is registered via [LevitScope.put], [LevitScope.lazyPut]
  /// or their async variants.
  ///
  /// *   [scopeId]: Unique identifier for the scope instance.
  /// *   [scopeName]: The name of the scope where the dependency is registered.
  /// *   [key]: The key under which the dependency is registered (type + optional tag).
  /// *   [info]: Metadata about the registered dependency.
  /// *   [source]: The method that triggered the event (e.g., 'put', 'lazyPut').
  /// *   [parentScopeId]: The ID of the parent scope, or null if root.
  void onDependencyRegister(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Called when a dependency is resolved (created or returned) via [LevitScope.find]
  /// or its variants.
  ///
  /// *   [scopeId]: Unique identifier for the scope instance.
  /// *   [scopeName]: The name of the scope where the dependency was found.
  /// *   [key]: The key of the resolved dependency.
  /// *   [info]: Metadata about the resolved dependency.
  /// *   [source]: The method that triggered the event (e.g., 'find', 'findAsync').
  /// *   [parentScopeId]: The ID of the parent scope, or null if root.
  void onDependencyResolve(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Called when a dependency is deleted via [LevitScope.delete] or [LevitScope.reset].
  ///
  /// *   [scopeId]: Unique identifier for the scope instance.
  /// *   [scopeName]: The name of the scope from which the dependency was deleted.
  /// *   [key]: The key of the deleted dependency.
  /// *   [info]: Metadata about the deleted dependency.
  /// *   [source]: The method that triggered the event (e.g., 'delete', 'reset').
  /// *   [parentScopeId]: The ID of the parent scope, or null if root.
  void onDependencyDelete(
      int scopeId, String scopeName, String key, LevitDependency info,
      {required String source, int? parentScopeId}) {}

  /// Called when a dependency instance is being created.
  ///
  /// This method allows you to wrap the creation logic, for example, to run it
  /// within a specific [Zone].
  ///
  /// *   [builder]: The function that creates the instance.
  /// *   [scope]: The scope where the dependency is being registered.
  /// *   [key]: The key of the dependency.
  /// *   [info]: Metadata about the dependency.
  ///
  /// Returns a new builder function that eventually calls [builder].
  /// If you don't need to wrap the builder, simply return [builder] (default behavior).
  S Function() onDependencyCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) =>
      builder;

  /// Called when a dependency's [onInit] method is about to be executed.
  ///
  /// This method allows you to wrap the initialization logic, for example, to
  /// capture reactive variables created during initialization.
  ///
  /// *   [onInit]: The original onInit function.
  /// *   [instance]: The dependency instance.
  /// *   [scope]: The scope where the dependency is registered.
  /// *   [key]: The key of the dependency.
  /// *   [info]: Metadata about the dependency.
  ///
  /// Returns a new void function that eventually calls [onInit].
  /// If you don't need to wrap onInit, simply return [onInit] (default behavior).
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitDependency info,
  ) =>
      onInit;
}
