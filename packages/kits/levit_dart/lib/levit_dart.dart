/// Pure Dart utility kit for Levit controllers and runtime workflows.
///
/// Layers everyday controller mixins, keyed async data, and loop execution on
/// top of `levit_dart_core` (hiding low-level `Ls` and `Lx` facades in favor of
/// [Levit]):
///
/// ### Kit utilities
/// * [LevitReactiveTasksMixin] / [LevitTasksMixin]: Named task scheduling,
///   [LevitTaskConflictPolicy], [LevitRetryPolicy], cooperative cancellation
///   ([LevitTaskContext]), and reactive progress selectors.
/// * [LevitAsyncMap] / [LevitAsyncMapEntry]: Task-backed keyed async data with
///   freshness, grace periods, and per-key observation.
/// * [LevitTimeMixin] / [LevitCountdown]: Lifecycle-owned debouncing,
///   throttling, periodic intervals, and elapsed-time countdowns.
/// * [LevitSelectionMixin]: Reactive single- and multi-selection state.
/// * [LevitLoopMixin] / [LevitLoopEngine] / [LevitLoopService]: Managed
///   periodic and isolate loops.
///
/// ### Additional entry points
/// * `package:levit_dart/tasks.dart`: Standalone `LevitTaskEngine`, structured
///   `LevitTaskGroup`, isolate tasks, caching, middleware, tracker, and sealed
///   `LevitTaskResult` unions.
/// * `package:levit_dart/levit_testing.dart`: Isolated `LevitTestScope` and
///   typed store overrides for tests.
///
/// @docImport 'package:levit_dart_core/levit_dart_core.dart';
/// @docImport 'src/kit_library.dart';
library;

export 'package:levit_dart_core/levit_dart_core.dart' hide Ls, Lx;
export 'src/kit_library.dart'
    show
        LevitAsyncMap,
        LevitAsyncMapEntry,
        LevitCountdown,
        LevitLoopEngine,
        LevitLoopMixin,
        LevitLoopService,
        LevitReactiveTasksMixin,
        LevitRetryPolicy,
        LevitSelectionMixin,
        LevitTaskCancelledException,
        LevitTaskConflictException,
        LevitTaskConflictPolicy,
        LevitTaskContext,
        LevitTaskDetails,
        LevitTaskDroppedException,
        LevitTaskMetadata,
        LevitTaskPhase,
        LevitTaskPriority,
        LevitTaskQueueFullException,
        LevitTaskSupersededException,
        LevitTasksMixin,
        LevitTimeMixin;
