part of '../levit_dart.dart';

// ============================================================================
// LevitScope - Extension for implicit scoping
// ============================================================================

/// Implicit scoping extensions for [LevitScope].
extension LevitScopeImplicitScopeExtension on LevitScope {
  /// Executes the [callback] within a [Zone] where this scope is active.
  ///
  /// Any calls to static methods like [Levit.find] or [Levit.put] inside the
  /// [callback] will automatically target this scope.
  ///
  /// Returns the result of the [callback].
  R run<R>(R Function() callback) {
    return runZoned(
      callback,
      zoneValues: {Levit.zoneScopeKey: this},
    );
  }
}
