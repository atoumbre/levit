/// Service Provider Interface (SPI) for cross-package integrations with `levit_scope`.
///
/// Exposes [LsSpi], [LevitDrainable], [LevitExecutionBoundary], and
/// [LevitScopeProgressObserver] for higher Levit layers without cluttering the
/// application-facing barrel.
///
/// @docImport 'src/scope_library.dart';
library;

export 'src/scope_library.dart'
    show
        LevitDrainable,
        LevitExecutionBoundary,
        LevitScopeProgressObserver,
        LsSpi;
