/// Pure Dart dependency injection and service locator.
///
/// This library provides the core dependency injection mechanism of the Levit framework.
/// It supports:
///
/// *   Singleton and factory registrations.
/// *   Lazy and async initialization.
/// *   Hierarchical scoping ([LevitScope]).
/// *   Lifecycle management via [LevitScopeDisposable].
library;

export 'src/core.dart' hide LevitScopeMiddlewareChain;
export 'src/middleware.dart';
