/// Service Provider Interface (SPI) for cross-package integrations with `levit_scope`.
///
/// Exposes scope drainage, execution boundary, progress observation, and zone
/// key hooks used by higher Levit layers without cluttering the app barrel.
library;

export 'src/scope_library.dart'
    show
        LevitDrainable,
        LevitExecutionBoundary,
        LevitScopeProgressObserver,
        LsSpi;
