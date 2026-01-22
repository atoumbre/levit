// ==========================================================================
// Lx Static API - Configuration, Proxy, Batching
// ==========================================================================

import 'core.dart';
import 'middlewares.dart';
import 'package:meta/meta.dart';
import 'watchers.dart';

/// Global accessor for reactive state management.
///
/// This class provides static access to core reactive state management functionality,
/// including configuration, proxy management, and middleware operations.
class Lx {
  static LevitReactiveObserver? get proxy => LevitStateCore.proxy;

  static set proxy(LevitReactiveObserver? value) {
    LevitStateCore.proxy = value;
  }

// --------------------------------------------------------------------------
// Configuration
// --------------------------------------------------------------------------

  /// Whether to capture stack traces on state changes (expensive).
  static bool get captureStackTrace => LevitStateCore.captureStackTrace;

  /// Global flag to enable/disable [LxWatch] performance monitoring.
  ///
  /// When `true` (default), [LxWatch] instances track execution statistics
  /// including run count, duration, and timing. This is useful for debugging
  /// and performance analysis but adds overhead.
  ///
  /// When `false`, [LxWatch] skips all timing measurements and stat updates,
  /// reducing overhead in production.
  ///
  /// Individual watchers can override this via their `enableMonitoring` parameter.
  ///
  /// ```dart
  /// // Disable globally for production
  /// Lx.enableWatchMonitoring = false;
  /// ```
  static bool enableWatchMonitoring = true;

  static set captureStackTrace(bool value) {
    LevitStateCore.captureStackTrace = value;
  }

// --------------------------------------------------------------------------
// Middlewares
// --------------------------------------------------------------------------

  /// Adds a middleware.
  static LevitReactiveMiddleware addMiddleware(
      LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.add(middleware);
  }

  /// Removes a middleware.
  static bool removeMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.remove(middleware);
  }

  /// Clears all middlewares. Use with caution.
  static void clearMiddlewares() {
    LevitReactiveMiddleware.clear();
  }

  static bool containsMiddleware(LevitReactiveMiddleware middleware) {
    return LevitReactiveMiddleware.contains(middleware);
  }

  static void runWithoutMiddleware(void Function() action) {
    LevitReactiveMiddleware.runWithoutMiddleware(action);
  }

// --------------------------------------------------------------------------
// Batching
// --------------------------------------------------------------------------

  static R batch<R>(R Function() callback) {
    return LevitStateCore.batch(callback);
  }

  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return LevitStateCore.batchAsync(callback);
  }

  static bool get isBatching => LevitStateCore.isBatching;

// --------------------------------------------------------------------------
// Async Zone Tracking (Internal)
// --------------------------------------------------------------------------

  /// Internal: Enters async tracking scope.
  @internal
  static void enterAsyncScope() {
    LevitStateCore.enterAsyncScope();
  }

  /// Internal: Exits async tracking scope.
  @internal
  static void exitAsyncScope() {
    LevitStateCore.exitAsyncScope();
  }

  @internal
  static Object get asyncComputedTrackerZoneKey =>
      LevitStateCore.asyncComputedTrackerZoneKey;
}
