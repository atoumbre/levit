/// Type-safe hierarchical dependency injection and lifecycle runtime for Dart.
///
/// `levit_scope` is reflection-free and relies on explicit types, optional
/// tags, and deterministic scope boundaries:
///
/// * [LevitScope]: Hierarchical dependency container with LIFO teardown and
///   value-free inspection via [LevitScopeDescription].
/// * [LevitScopeDisposable] & [LevitDisposable]: Explicit initialization and
///   asynchronous cleanup contracts, with failures aggregated into
///   [LevitDisposalException].
/// * [LevitScopeMiddleware]: Global interception of scope and DI lifecycle
///   events.
/// * [Ls]: Low-level zone-scoped static proxy (hidden by high-level kits in
///   favor of `Levit`).
///
/// ```dart
/// final scope = LevitScope.root('app');
/// scope.put(() => ApiClient());
/// final api = scope.find<ApiClient>();
/// await scope.dispose();
/// ```
///
/// Cross-package runtime hooks live in `package:levit_scope/spi.dart`.
///
/// @docImport 'src/scope_library.dart';
library;

export 'src/scope_library.dart'
    hide
        LevitDrainable,
        LevitExecutionBoundary,
        LevitScopeProgressObserver,
        LsSpi;
