/// Service Provider Interface (SPI) for cross-package integrations with `levit_reactive`.
///
/// Exposes [LxSpi], [LxBase], [LxAsyncResource], [LevitReactiveNotifier],
/// [LevitReactiveObserver], [LevitReactiveReadResolver],
/// [LevitReactiveMetadataObserver], and [LxListenerContext] for higher Levit
/// layers (`levit_dart_core`, `levit_flutter_core`, `levit_monitor`) and
/// tooling without cluttering the application-facing barrel.
///
/// @docImport 'src/reactive_library.dart';
library;

export 'src/reactive_library.dart'
    show
        LevitReactiveMetadataObserver,
        LevitReactiveNotifier,
        LevitReactiveObserver,
        LevitReactiveReadResolver,
        LxAsyncResource,
        LxBase,
        LxListenerContext,
        LxSpi;
