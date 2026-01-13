part of '../levit_dart.dart';

// ============================================================================
// LevitMiddleware - Unified Middleware System
// ============================================================================

/// A unified base class for Levit middlewares.
///
/// [LevitMiddleware] combines the capabilities of [LevitStateMiddleware] (for reactive
/// state changes) and [LevitScopeMiddleware] (for dependency injection events).
///
/// Use this class to create integrated tools like loggers, analytics trackers,
/// or devtools bridges that require a holistic view of the application state
/// and its structure.
abstract class LevitMiddleware extends LevitStateMiddleware
    implements LevitScopeMiddleware {
  /// Called when a reactive variable is registered with its owner.
  ///
  /// * [reactive]: The reactive variable being registered.
  /// * [ownerId]: The registration key of the owner (typically a [LevitController]).
  void onReactiveRegister(LxReactive reactive, String ownerId) {}

  // --- LevitScopeMiddleware Implementation ---

  @override
  void onRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitBindingEntry info, {
    required String source,
    int? parentScopeId,
  }) {}

  @override
  void onResolve(
    int scopeId,
    String scopeName,
    String key,
    LevitBindingEntry info, {
    required String source,
    int? parentScopeId,
  }) {}

  @override
  void onDelete(
    int scopeId,
    String scopeName,
    String key,
    LevitBindingEntry info, {
    required String source,
    int? parentScopeId,
  }) {}

  @override
  S Function() onCreate<S>(
    S Function() builder,
    LevitScope scope,
    String key,
    LevitBindingEntry info,
  ) {
    return builder;
  }

  @override
  void Function() onDependencyInit<S>(
    void Function() onInit,
    S instance,
    LevitScope scope,
    String key,
    LevitBindingEntry info,
  ) {
    return onInit;
  }
}
