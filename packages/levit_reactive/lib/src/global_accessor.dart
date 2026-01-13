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
  static LevitStateObserver? get proxy => LevitSateCore.proxy;

  static set proxy(LevitStateObserver? value) {
    LevitSateCore.proxy = value;
  }

// --------------------------------------------------------------------------
// Configuration
// --------------------------------------------------------------------------

  /// Whether to capture stack traces on state changes (expensive).
  static bool get captureStackTrace => LevitSateCore.captureStackTrace;

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
    LevitSateCore.captureStackTrace = value;
  }

// --------------------------------------------------------------------------
// Middlewares
// --------------------------------------------------------------------------

  /// Adds a middleware.
  static LevitStateMiddleware addMiddleware(LevitStateMiddleware middleware) {
    return LevitStateMiddleware.add(middleware);
  }

  /// Removes a middleware.
  static bool removeMiddleware(LevitStateMiddleware middleware) {
    return LevitStateMiddleware.remove(middleware);
  }

  /// Clears all middlewares. Use with caution.
  static void clearMiddlewares() {
    LevitStateMiddleware.clear();
  }

  static bool containsMiddleware(LevitStateMiddleware middleware) {
    return LevitStateMiddleware.contains(middleware);
  }

  static void runWithoutMiddleware(void Function() action) {
    LevitStateMiddleware.runWithoutMiddleware(action);
  }

// --------------------------------------------------------------------------
// Batching
// --------------------------------------------------------------------------

  static R batch<R>(R Function() callback) {
    return LevitSateCore.batch(callback);
  }

  static Future<R> batchAsync<R>(Future<R> Function() callback) {
    return LevitSateCore.batchAsync(callback);
  }

  static bool get isBatching => LevitSateCore.isBatching;

// --------------------------------------------------------------------------
// Async Zone Tracking (Internal)
// --------------------------------------------------------------------------

  /// Internal: Enters async tracking scope.
  @internal
  static void enterAsyncScope() {
    LevitSateCore.enterAsyncScope();
  }

  /// Internal: Exits async tracking scope.
  @internal
  static void exitAsyncScope() {
    LevitSateCore.exitAsyncScope();
  }

  @internal
  static Object get asyncComputedTrackerZoneKey =>
      LevitSateCore.asyncComputedTrackerZoneKey;
}
