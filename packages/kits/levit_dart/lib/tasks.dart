/// Advanced task orchestration APIs for Levit.
///
/// Exports [LevitTaskEngine], structured concurrency via [LevitTaskGroup],
/// isolate tasks ([LevitIsolateTask]), caching ([LevitTaskCacheProvider],
/// [LevitTaskCachePolicy]), global instrumentation ([LevitTaskMiddleware],
/// [LevitTaskTracker]), and exhaustive [LevitTaskResult] unions alongside the
/// everyday task mixins ([LevitTasksMixin], [LevitReactiveTasksMixin]).
///
/// ```dart
/// import 'package:levit_dart/levit_dart.dart';
/// import 'package:levit_dart/tasks.dart';
///
/// final engine = LevitTaskEngine(maxConcurrent: 4);
/// final outcome = await engine.submit((ctx) => fetchData()).outcome;
/// await engine.dispose();
/// ```
///
/// @docImport 'src/kit_library.dart';
library;

export 'src/kit_library.dart'
    show
        LevitIsolateTask,
        LevitIsolateTaskContext,
        LevitReactiveTasksMixin,
        LevitRetryPolicy,
        LevitTaskCachePolicy,
        LevitTaskCacheProvider,
        LevitTaskCancellationKind,
        LevitTaskCancellationReason,
        LevitTaskCancelled,
        LevitTaskCancelledException,
        LevitTaskConflictException,
        LevitTaskConflictPolicy,
        LevitTaskContext,
        LevitTaskDetails,
        LevitTaskDropped,
        LevitTaskDroppedException,
        LevitTaskEngine,
        LevitTaskEvent,
        LevitTaskEventType,
        LevitTaskExecution,
        LevitTaskExecutionSummary,
        LevitTaskFailure,
        LevitTaskGroup,
        LevitTaskGroupException,
        LevitTaskGroupPolicy,
        LevitTaskMetadata,
        LevitTaskMiddleware,
        LevitTaskOutcome,
        LevitTaskPhase,
        LevitTaskPriority,
        LevitTaskQueueFullException,
        LevitTaskResult,
        LevitTaskSkipReason,
        LevitTaskSubmissionDisposition,
        LevitTaskSuccess,
        LevitTaskSuperseded,
        LevitTaskSupersededException,
        LevitTaskTracker,
        LevitTaskTreeSnapshot,
        LevitTasksMixin;
