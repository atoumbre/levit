/// Pure Dart reactive runtime for state propagation and derivation.
///
/// This package provides Levit's low-level reactive engine.
/// It is dependency-free and focuses on deterministic, fine-grained updates.
///
/// ### Core abstractions
/// * [LxReactive]: base interface for reactive sources.
/// * [Lx]: static runtime gateway for creation, batching, and middleware.
/// * [LxComputed]: derived state with automatic dependency tracking.
///
/// `levit_reactive` is the foundation used by higher Levit layers and can be
/// used directly in any Dart runtime.
library;

export 'src/reactive_library.dart'
    hide
        LevitReactiveMetadataObserver,
        LevitReactiveNotifier,
        LevitReactiveObserver,
        LevitReactiveReadResolver,
        LxAsyncResource,
        LxBase,
        LxSpi;
