/// Pure Dart reactive runtime for state propagation and derivation.
///
/// This package provides Levit's dependency-free reactive engine focused on
/// deterministic, fine-grained updates and explicit async lifecycle cleanup.
///
/// ### Core abstractions
/// * [LxReadable] / [LxReactive]: Read-only and owner-controlled reactive
///   source interfaces.
/// * [LxVar], [LxBool], [LxInt], [LxDouble]: Mutable reactive state primitives
///   (`.lx` extensions, with `.asReadable` for read-only exposure).
/// * [LxList], [LxMap], [LxSet], [LxMapEntry], [LxListEntry]: Reactive
///   collections with fine-grained entry observation.
/// * [LxComputed] / [LxAsyncComputed]: Synchronous and asynchronous derived
///   state with automatic dependency tracking and [LxAsyncConcurrency].
/// * [LxFuture], [LxStream], [LxStatus]: Async reactive sources and statuses.
/// * [LxWorker]: Reactive side-effect observers with cooperative cancellation.
/// * [Lx] & [LevitReactiveMiddleware]: Batching, untracked reads, and state
///   middleware hooks.
///
/// ```dart
/// final count = 0.lx;
/// final doubled = LxComputed(() => count() * 2);
/// count.value = 3; // doubled() == 6
/// await doubled.close();
/// await count.close();
/// ```
///
/// Cross-package runtime integration hooks live in
/// `package:levit_reactive/spi.dart`.
///
/// @docImport 'src/reactive_library.dart';
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
