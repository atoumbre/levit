part of '../kit_library.dart';

/// Priority levels for task execution.
///
/// {@category Tasks & Concurrency}
enum LevitTaskPriority {
  /// High priority tasks are processed before normal tasks.
  high,

  /// Default priority for tasks.
  normal,

  /// Low priority tasks are processed after other tasks.
  low,
}

/// Defines what happens when a logical task ID already has pending work.
///
/// {@category Tasks & Concurrency}
enum LevitTaskConflictPolicy {
  /// Synchronously rejects the new submission with a `LevitTaskConflictException`
  /// (exported by `tasks.dart`).
  reject,

  /// Shares the result of the latest outstanding execution.
  join,

  /// Ignores the new submission; its handle completes with a
  /// `LevitTaskDroppedException` (exported by `tasks.dart`).
  drop,

  /// Cooperatively cancels outstanding work (completing prior handles with a
  /// `LevitTaskSupersededException`) and admits the replacement.
  restart,

  /// Runs every submission in FIFO order for the same logical task ID.
  enqueue,

  /// Retains one trailing execution and replaces it with the latest submission.
  coalesceLatest,
}

/// The scheduling phase of a tracked task execution (exposed via
/// [LevitTaskDetails.phase] and `LevitTaskEvent.phase` in `tasks.dart`).
///
/// {@category Tasks & Concurrency}
enum LevitTaskPhase {
  /// Admitted and waiting in the priority queue for a worker slot.
  queued,

  /// Currently executing an attempt on a worker slot.
  running,

  /// Waiting for its retry backoff delay before the next attempt.
  retryWaiting,

  /// Reached a terminal state (succeeded, failed, cancelled, dropped, or rejected).
  completed,
}

/// Terminal outcomes for task executions and rejected submissions.
///
/// {@category Tasks & Concurrency}
enum LevitTaskOutcome {
  /// Task completed normally and produced a result.
  succeeded,

  /// Task exhausted retries (or failed with a non-retryable error).
  failed,

  /// Task was cooperatively cancelled (requested, owner closed, deadline, etc.).
  cancelled,

  /// Execution was replaced by a newer submission (`restart` / `coalesceLatest`).
  superseded,

  /// Submission was ignored under [LevitTaskConflictPolicy.drop].
  dropped,

  /// Submission was rejected synchronously under [LevitTaskConflictPolicy.reject].
  rejected,

  /// Task returned a fresh result directly from cache without running.
  cacheHit,
}

/// Lifecycle event types emitted by [LevitTaskEngine].
///
/// {@category Tasks & Concurrency}
enum LevitTaskEventType {
  /// Execution was admitted and added to the priority queue.
  queued,

  /// Execution acquired a worker slot and started an attempt.
  started,

  /// Running execution reported a progress update.
  progress,

  /// Attempt failed with a retryable error and a retry timer was scheduled.
  retryScheduled,

  /// Execution completed successfully.
  finished,

  /// Execution terminated with an unhandled error.
  failed,

  /// Execution was skipped (cache hit, cancelled, superseded, or dropped).
  skipped,

  /// Submission was rejected due to a conflict or full queue.
  rejected,

  /// Submission replaced a pending trailing task under `coalesceLatest`.
  coalesced,
}

/// Reasons why a task execution was skipped without completing normally.
///
/// {@category Tasks & Concurrency}
enum LevitTaskSkipReason {
  /// Served directly from [LevitTaskCacheProvider].
  cacheHit,

  /// Cancelled while still waiting in the queue.
  cancelledWhileQueued,

  /// Cancelled after dequeueing but before the task body started.
  cancelledBeforeStart,

  /// Cancelled while or after the task body ran.
  cancelledAfterRun,

  /// Superseded by a newer submission for the same logical task ID.
  superseded,

  /// Ignored under [LevitTaskConflictPolicy.drop].
  dropped,
}

/// Describes a logical task conflict rejected by the engine.
///
/// {@category Tasks & Concurrency}
class LevitTaskConflictException implements Exception {
  /// The logical ID that already has outstanding work.
  final String taskId;

  /// Creates a conflict exception for [taskId].
  const LevitTaskConflictException(this.taskId);

  @override
  String toString() =>
      'LevitTaskConflictException: task "$taskId" already has outstanding work.';
}

/// Exception indicating that a task execution was cooperatively cancelled.
///
/// Thrown by [LevitTaskContext.throwIfCancelled] as well as by the task engine
/// or task group when an execution is cancelled while queued, before start,
/// after run, on deadline expiration, or on owner/engine disposal.
///
/// {@category Tasks & Concurrency}
class LevitTaskCancelledException implements Exception {
  /// The logical task ID.
  final String taskId;

  /// The unique execution ID.
  final String executionId;

  /// Structured reason explaining why cancellation occurred.
  final LevitTaskCancellationReason reason;

  /// Creates a cooperative cancellation exception.
  const LevitTaskCancelledException(
    this.taskId,
    this.executionId, {
    this.reason = const LevitTaskCancellationReason(
      LevitTaskCancellationKind.requested,
    ),
  });

  @override
  String toString() =>
      'LevitTaskCancelledException: execution "$executionId" '
      'for task "$taskId" was cancelled.';
}

/// Stable, low-cardinality metadata attached to task executions.
///
/// {@category Tasks & Concurrency}
class LevitTaskMetadata {
  /// A stable human-readable operation name.
  final String? debugName;

  /// A stable task category used for filtering and aggregate UI.
  final String? category;

  /// Whether this task may drive blocking user-interface state.
  final bool blocksUserInteraction;

  /// Whether task diagnostics must be treated as sensitive.
  final bool sensitive;

  /// Additional application-defined, low-cardinality attributes.
  final Map<String, Object?> attributes;

  /// Creates task metadata.
  const LevitTaskMetadata({
    this.debugName,
    this.category,
    this.blocksUserInteraction = false,
    this.sensitive = false,
    this.attributes = const {},
  });

  /// Empty task metadata.
  static const none = LevitTaskMetadata();
}

class _LevitTaskCancellation {
  bool _isCancelled = false;
  Completer<void>? _cancelled;

  bool get isCancelled => _isCancelled;
  Future<void> get cancelled {
    final completed = _cancelled ??= Completer<void>();
    if (_isCancelled && !completed.isCompleted) completed.complete();
    return completed.future;
  }

  LevitTaskCancellationReason? reason;

  void cancel([
    LevitTaskCancellationReason reason = const LevitTaskCancellationReason(
      LevitTaskCancellationKind.requested,
    ),
  ]) {
    if (_isCancelled) return;
    _isCancelled = true;
    this.reason = reason;
    _cancelled?.complete();
  }
}

/// Context passed to every task attempt.
///
/// {@category Tasks & Concurrency}
class LevitTaskContext {
  /// The stable logical task ID.
  final String taskId;

  /// A unique ID for this admitted execution.
  final String executionId;

  /// The one-based attempt number.
  final int attempt;

  final _LevitTaskCancellation _cancellation;

  /// The [LevitTaskGroup] owning this task execution.
  final LevitTaskGroup group;

  /// Effective absolute deadline for this execution, if any.
  final DateTime? deadline;
  final void Function(double value) _reportProgress;

  LevitTaskContext._({
    required this.taskId,
    required this.executionId,
    required this.attempt,
    required this.group,
    this.deadline,
    required _LevitTaskCancellation cancellation,
    required void Function(double value) reportProgress,
  }) : _cancellation = cancellation,
       _reportProgress = reportProgress;

  /// Whether cooperative cancellation has been requested.
  bool get isCancelled => _cancellation.isCancelled;

  /// Structured reason for cancellation, or `null` if not cancelled.
  LevitTaskCancellationReason? get cancellationReason => _cancellation.reason;

  /// Completes when cooperative cancellation is requested.
  Future<void> get cancelled => _cancellation.cancelled;

  /// Throws [LevitTaskCancelledException] when cancellation was requested.
  void throwIfCancelled() {
    if (isCancelled) {
      throw LevitTaskCancelledException(
        taskId,
        executionId,
        reason: _cancellation.reason!,
      );
    }
  }

  /// Reports progress in the inclusive `0.0` to `1.0` range.
  ///
  /// Throws a [RangeError] if [value] is non-finite or outside `[0.0, 1.0]`,
  /// and throws [LevitTaskCancelledException] if cancellation was requested.
  void reportProgress(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
    throwIfCancelled();
    _reportProgress(value);
  }
}

/// Message-safe context provided inside a task isolate.
///
/// {@category Tasks & Concurrency}
class LevitIsolateTaskContext {
  /// The stable logical task ID.
  final String taskId;

  /// A unique ID for this admitted execution.
  final String executionId;

  /// The one-based attempt number.
  final int attempt;

  final LevitIsolateReceivePort _cancellationPort;
  final LevitIsolateSendPort _eventPort;
  bool _isCancelled = false;

  /// Structured cancellation reason received by the isolate, or `null` if not
  /// cancelled.
  LevitTaskCancellationReason? cancellationReason;
  final Completer<void> _cancelled = Completer<void>();

  LevitIsolateTaskContext._({
    required this.taskId,
    required this.executionId,
    required this.attempt,
    required LevitIsolateReceivePort cancellationPort,
    required LevitIsolateSendPort eventPort,
  }) : _cancellationPort = cancellationPort,
       _eventPort = eventPort {
    _cancellationPort.listen((reason) {
      if (_isCancelled) return;
      _isCancelled = true;
      cancellationReason =
          reason as LevitTaskCancellationReason? ??
          const LevitTaskCancellationReason(
            LevitTaskCancellationKind.requested,
          );
      _cancelled.complete();
    });
  }

  /// Whether cooperative cancellation has reached the isolate.
  bool get isCancelled => _isCancelled;

  /// Completes when cooperative cancellation reaches the isolate.
  Future<void> get cancelled => _cancelled.future;

  /// Throws [LevitTaskCancelledException] when cancellation was requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw LevitTaskCancelledException(
        taskId,
        executionId,
        reason: cancellationReason!,
      );
    }
  }

  /// Reports progress in the inclusive `0.0` to `1.0` range back to the host
  /// isolate.
  ///
  /// Throws a [RangeError] if [value] is non-finite or outside `[0.0, 1.0]`,
  /// and throws [LevitTaskCancelledException] if cancellation was requested.
  void reportProgress(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
    throwIfCancelled();
    _eventPort.send((_IsolateTaskMessage.progress, value));
  }

  void _close() => _cancellationPort.close();
}

/// A top-level or static task entrypoint suitable for isolate execution.
///
/// {@category Tasks & Concurrency}
typedef LevitIsolateTask<I, T> =
    FutureOr<T> Function(I input, LevitIsolateTaskContext context);

/// Structured lifecycle event emitted by [LevitTaskEngine].
///
/// {@category Tasks & Concurrency}
class LevitTaskEvent {
  /// The kind of lifecycle transition represented by this event.
  final LevitTaskEventType type;

  /// Identifier of the owning [LevitTaskGroup], if any.
  final String? groupId;

  /// Identifier of the parent [LevitTaskGroup], if any.
  final String? parentGroupId;

  /// Effective absolute deadline for this execution, if any.
  final DateTime? deadline;

  /// Structured cancellation reason, when cancelled.
  final LevitTaskCancellationReason? cancellationReason;

  /// Stable logical task ID.
  final String taskId;

  /// Unique admitted execution ID.
  final String executionId;

  /// Diagnostic path of the owner that scheduled the execution.
  final String ownerPath;

  /// Scheduling phase after this transition.
  final LevitTaskPhase phase;

  /// Low-cardinality task metadata.
  final LevitTaskMetadata metadata;

  /// Assigned scheduling priority.
  final LevitTaskPriority priority;

  /// Attempt counter (`0` while queued, then 1-based).
  final int attempt;

  /// Configured maximum retry count for this execution.
  final int maxRetries;

  /// Timestamp when this event was emitted.
  final DateTime timestamp;

  /// Timestamp when this execution was queued.
  final DateTime queuedAt;

  /// Timestamp when execution started, if started.
  final DateTime? startedAt;

  /// Timestamp when execution reached a terminal state, if finished.
  final DateTime? finishedAt;

  /// Time spent waiting in the queue before starting, if measured.
  final Duration? queueDuration;

  /// Elapsed execution time from start to finish, if measured.
  final Duration? runDuration;

  /// Scheduled delay before the next retry attempt, for [LevitTaskEventType.retryScheduled].
  final Duration? retryIn;

  /// Reported progress in `[0.0, 1.0]`, if available.
  final double? progress;

  /// Reason the execution was skipped, for [LevitTaskEventType.skipped].
  final LevitTaskSkipReason? skipReason;

  /// Terminal outcome, when complete.
  final LevitTaskOutcome? outcome;

  /// Unhandled error object, for [LevitTaskEventType.failed] or retryable failures.
  final Object? error;

  /// Stack trace associated with [error], if available.
  final StackTrace? stackTrace;

  /// Whether this execution runs in a spawned `Isolate`.
  final bool runsInIsolate;

  /// Compatibility view of [LevitTaskMetadata.debugName].
  String? get debugName => metadata.debugName;

  /// Compatibility alias for [runsInIsolate].
  bool get runInIsolate => runsInIsolate;

  /// Creates a structured [LevitTaskEvent].
  LevitTaskEvent({
    required this.type,
    this.groupId,
    this.parentGroupId,
    this.deadline,
    this.cancellationReason,
    required this.taskId,
    String? executionId,
    this.ownerPath = '?',
    LevitTaskPhase? phase,
    LevitTaskMetadata? metadata,
    this.priority = LevitTaskPriority.normal,
    this.attempt = 0,
    this.maxRetries = 0,
    DateTime? queuedAt,
    this.startedAt,
    this.finishedAt,
    this.queueDuration,
    this.runDuration,
    this.retryIn,
    this.progress,
    this.skipReason,
    this.outcome,
    this.error,
    this.stackTrace,
    bool? runsInIsolate,
    bool? runInIsolate,
    String? debugName,
    DateTime? timestamp,
  }) : executionId = executionId ?? taskId,
       phase = phase ?? _phaseForEvent(type),
       metadata =
           metadata ??
           (debugName == null
               ? LevitTaskMetadata.none
               : LevitTaskMetadata(debugName: debugName)),
       runsInIsolate = runsInIsolate ?? runInIsolate ?? false,
       timestamp = timestamp ?? DateTime.now(),
       queuedAt = queuedAt ?? timestamp ?? DateTime.now();

  static LevitTaskPhase _phaseForEvent(LevitTaskEventType type) {
    return switch (type) {
      LevitTaskEventType.queued ||
      LevitTaskEventType.coalesced => LevitTaskPhase.queued,
      LevitTaskEventType.started ||
      LevitTaskEventType.progress => LevitTaskPhase.running,
      LevitTaskEventType.retryScheduled => LevitTaskPhase.retryWaiting,
      LevitTaskEventType.finished ||
      LevitTaskEventType.failed ||
      LevitTaskEventType.skipped ||
      LevitTaskEventType.rejected => LevitTaskPhase.completed,
    };
  }
}

/// Receives structured task events from every [LevitTaskEngine] in this isolate.
///
/// Registrations are isolate-global; pass a stable `token` to [add] and remove
/// it via [removeByToken] during teardown. Exceptions thrown inside
/// [onTaskEvent] are isolated so instrumentation cannot disrupt application work.
///
/// {@category Tasks & Concurrency}
abstract class LevitTaskMiddleware {
  /// Creates a task middleware.
  const LevitTaskMiddleware();

  static final List<LevitTaskMiddleware> _middlewares = [];
  static final Map<Object, LevitTaskMiddleware> _middlewaresByToken = {};

  /// Handles one structured task event.
  void onTaskEvent(LevitTaskEvent event);

  /// Registers [middleware] globally, optionally replacing the same [token].
  static T add<T extends LevitTaskMiddleware>(T middleware, {Object? token}) {
    if (token != null) {
      final previous = _middlewaresByToken[token];
      if (identical(previous, middleware)) return middleware;
      if (previous != null) _middlewares.remove(previous);
      _middlewaresByToken[token] = middleware;
    }
    if (!_middlewares.contains(middleware)) _middlewares.add(middleware);
    return middleware;
  }

  /// Removes [middleware] and any tokens attached to it.
  static bool remove(LevitTaskMiddleware middleware) {
    final removed = _middlewares.remove(middleware);
    _middlewaresByToken.removeWhere(
      (_, current) => identical(current, middleware),
    );
    return removed;
  }

  /// Removes the middleware registered for [token].
  static bool removeByToken(Object token) {
    final middleware = _middlewaresByToken.remove(token);
    return middleware != null && _middlewares.remove(middleware);
  }

  /// Whether [middleware] is registered.
  static bool contains(LevitTaskMiddleware middleware) =>
      _middlewares.contains(middleware);

  static void _emit(LevitTaskEvent event) {
    for (final middleware in List<LevitTaskMiddleware>.of(
      _middlewares,
      growable: false,
    )) {
      try {
        middleware.onTaskEvent(event);
      } catch (_) {
        // Instrumentation is isolated from application work by design.
      }
    }
  }
}

/// How a submitted task related to existing work for the same logical task ID.
///
/// {@category Tasks & Concurrency}
enum LevitTaskSubmissionDisposition {
  /// Admitted as a fresh independent execution.
  admitted,

  /// Attached to an existing in-flight execution under [LevitTaskConflictPolicy.join].
  joined,

  /// Ignored under [LevitTaskConflictPolicy.drop].
  dropped,

  /// Replaced prior outstanding execution(s) under [LevitTaskConflictPolicy.restart].
  restarted,

  /// Replaced or queued as the single trailing slot under [LevitTaskConflictPolicy.coalesceLatest].
  coalesced,
}

/// A lightweight handle for one scheduled or joined execution.
///
/// [result] is pre-marked with `.ignore()` internally so callers that only
/// await [outcome] will not trigger unhandled zone errors. Calling [cancel] on
/// a [LevitTaskSubmissionDisposition.joined] handle cancels the shared
/// underlying execution.
///
/// {@category Tasks & Concurrency}
class LevitTaskExecution<T> {
  /// Stable logical task ID.
  final String taskId;

  /// Unique admitted execution ID.
  final String executionId;

  /// How this submission was handled.
  final LevitTaskSubmissionDisposition disposition;

  /// Successful nullable values are preserved. Skipped work throws a typed exception.
  final Future<T> result;

  /// Observes every terminal state without throwing.
  late final Future<LevitTaskResult<T>> outcome = result
      .then<LevitTaskResult<T>>(
        LevitTaskSuccess<T>.new,
        onError:
            (Object error, StackTrace stack) => switch (error) {
              LevitTaskSupersededException() => LevitTaskSuperseded<T>(),
              LevitTaskCancelledException(:final reason) =>
                LevitTaskCancelled<T>(reason),
              LevitTaskDroppedException() => LevitTaskDropped<T>(),
              _ => LevitTaskFailure<T>(error, stack),
            },
      );

  final void Function() _cancel;
  final LevitDisposalFailure? Function()? _takeCleanupFailure;

  LevitTaskExecution._({
    required this.taskId,
    required this.executionId,
    required this.disposition,
    required this.result,
    required void Function() cancel,
    LevitDisposalFailure? Function()? takeCleanupFailure,
  }) : _cancel = cancel,
       _takeCleanupFailure = takeCleanupFailure {
    // A handle may be observed through outcome later. Mark the source handled
    // immediately, without eagerly allocating an unused outcome future/value.
    // ignore() retains the result/error for later result and outcome listeners.
    result.ignore();
  }

  /// Cooperatively cancels this execution.
  void cancel() => _cancel();
}

/// A dependency-free summary of one task execution retained by [LevitTaskTracker].
///
/// {@category Tasks & Concurrency}
class LevitTaskExecutionSummary {
  /// Stable logical task ID.
  final String taskId;

  /// Unique admitted execution ID.
  final String executionId;

  /// Diagnostic path of the scheduling owner.
  final String ownerPath;

  /// Owning [LevitTaskGroup] ID, if any.
  final String? groupId;

  /// Parent [LevitTaskGroup] ID, if any.
  final String? parentGroupId;

  /// Effective absolute deadline, if any.
  final DateTime? deadline;

  /// Structured cancellation reason, when cancelled.
  final LevitTaskCancellationReason? cancellationReason;

  /// Latest scheduling phase.
  final LevitTaskPhase phase;

  /// Stable task metadata.
  final LevitTaskMetadata metadata;

  /// Assigned scheduling priority.
  final LevitTaskPriority priority;

  /// Latest attempt count (`0` while queued, then 1-based).
  final int attempt;

  /// Timestamp when queued.
  final DateTime queuedAt;

  /// Timestamp when execution started, if started.
  final DateTime? startedAt;

  /// Timestamp when execution finished, if finished.
  final DateTime? finishedAt;

  /// Measured queue wait duration, if available.
  final Duration? queueDuration;

  /// Measured run duration, if available.
  final Duration? runDuration;

  /// Latest progress in `[0.0, 1.0]`.
  final double progress;

  /// Terminal outcome, when complete.
  final LevitTaskOutcome? outcome;

  /// Latest failure error object, if any.
  final Object? error;

  /// Stack trace associated with [error], if any.
  final StackTrace? stackTrace;

  /// Creates a task execution summary.
  const LevitTaskExecutionSummary({
    required this.taskId,
    required this.executionId,
    required this.ownerPath,
    this.groupId,
    this.parentGroupId,
    this.deadline,
    this.cancellationReason,
    required this.phase,
    required this.metadata,
    required this.priority,
    required this.attempt,
    required this.queuedAt,
    this.startedAt,
    this.finishedAt,
    this.queueDuration,
    this.runDuration,
    this.progress = 0,
    this.outcome,
    this.error,
    this.stackTrace,
  });

  /// Creates an initial [LevitTaskExecutionSummary] from [event].
  factory LevitTaskExecutionSummary.fromEvent(LevitTaskEvent event) {
    return LevitTaskExecutionSummary(
      taskId: event.taskId,
      executionId: event.executionId,
      ownerPath: event.ownerPath,
      groupId: event.groupId,
      parentGroupId: event.parentGroupId,
      deadline: event.deadline,
      cancellationReason: event.cancellationReason,
      phase: event.phase,
      metadata: event.metadata,
      priority: event.priority,
      attempt: event.attempt,
      queuedAt: event.queuedAt,
      startedAt: event.startedAt,
      finishedAt: event.finishedAt,
      queueDuration: event.queueDuration,
      runDuration: event.runDuration,
      progress: event.progress ?? 0,
      outcome: event.outcome,
      error: event.error,
      stackTrace: event.stackTrace,
    );
  }

  /// Returns an updated summary incorporating [event] while preserving earlier
  /// timestamps, durations, progress, and outcome when omitted in [event].
  LevitTaskExecutionSummary apply(LevitTaskEvent event) {
    return LevitTaskExecutionSummary(
      taskId: taskId,
      executionId: executionId,
      ownerPath: event.ownerPath,
      groupId: event.groupId,
      parentGroupId: event.parentGroupId,
      deadline: event.deadline,
      cancellationReason: event.cancellationReason,
      phase: event.phase,
      metadata: event.metadata,
      priority: event.priority,
      attempt: event.attempt,
      queuedAt: event.queuedAt,
      startedAt: event.startedAt ?? startedAt,
      finishedAt: event.finishedAt ?? finishedAt,
      queueDuration: event.queueDuration ?? queueDuration,
      runDuration: event.runDuration ?? runDuration,
      progress: event.progress ?? progress,
      outcome: event.outcome ?? outcome,
      error: event.error,
      stackTrace: event.stackTrace,
    );
  }
}

/// Optional reactive middleware for application-level aggregate task UI.
///
/// Registration is explicit:
/// `own(LevitTaskTracker()..attach())`.
///
/// {@category Tasks & Concurrency}
class LevitTaskTracker extends LevitTaskMiddleware implements LevitDisposable {
  /// Maximum number of terminal summaries retained.
  final int maxHistory;

  /// Summaries keyed by execution ID.
  final executions = LxMap<String, LevitTaskExecutionSummary>().named(
    'taskExecutions',
  );

  /// Reactive flag that is `true` while any non-completed tracked execution
  /// has `metadata.blocksUserInteraction == true`.
  late final LxComputed<bool> hasBlockingTasks = (() {
    return executions.values.any(
      (summary) =>
          summary.phase != LevitTaskPhase.completed &&
          summary.metadata.blocksUserInteraction,
    );
  }).lx.named('hasBlockingTasks');

  bool _attached = false;
  bool _disposed = false;

  /// Creates a detached tracker retaining up to [maxHistory] terminal summaries
  /// (defaults to `100`; throws [RangeError] if negative).
  LevitTaskTracker({this.maxHistory = 100}) {
    if (maxHistory < 0) {
      throw RangeError.range(maxHistory, 0, null, 'maxHistory');
    }
  }

  /// Registers this tracker as global [LevitTaskMiddleware] (optionally under
  /// [token]) and returns `this` for cascade chaining.
  ///
  /// Throws a [StateError] if already disposed.
  LevitTaskTracker attach({Object? token}) {
    if (_disposed) {
      throw StateError('A disposed LevitTaskTracker cannot be attached.');
    }
    LevitTaskMiddleware.add(this, token: token);
    _attached = true;
    return this;
  }

  @override
  void onTaskEvent(LevitTaskEvent event) {
    if (_disposed) return;
    final current = executions[event.executionId];
    executions[event.executionId] =
        current == null
            ? LevitTaskExecutionSummary.fromEvent(event)
            : current.apply(event);
    _prune();
  }

  void _prune() {
    final terminalIds = executions.entries
        .where((entry) => entry.value.phase == LevitTaskPhase.completed)
        .map((entry) => entry.key)
        .toList(growable: false);
    final removeCount = terminalIds.length - maxHistory;
    for (var index = 0; index < removeCount; index++) {
      executions.remove(terminalIds[index]);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_attached) LevitTaskMiddleware.remove(this);
    _attached = false;
    hasBlockingTasks.close();
    executions.close();
  }
}

/// Interface for task result caching.
///
/// Ships with [LevitTaskCacheProvider.inMemory] for in-memory caching. Custom
/// or persistent storage adapters can implement this interface.
///
/// {@category Tasks & Concurrency}
abstract class LevitTaskCacheProvider {
  /// Base constructor.
  const LevitTaskCacheProvider();

  /// Writes [data] to the cache under [key].
  Future<void> write(String key, Map<String, dynamic> data);

  /// Reads cached data for [key]. Returns `null` if not found.
  Future<Map<String, dynamic>?> read(String key);

  /// Deletes cached data for [key].
  Future<void> delete(String key);

  /// Creates a default in-memory [LevitTaskCacheProvider].
  factory LevitTaskCacheProvider.inMemory() = _InMemoryTaskCacheProvider;
}

/// A default in-memory implementation of [LevitTaskCacheProvider].
class _InMemoryTaskCacheProvider implements LevitTaskCacheProvider {
  final Map<String, Map<String, dynamic>> _cache = {};

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    _cache[key] = data;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async => _cache[key];

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
  }
}

/// Configuration for caching a task's result.
///
/// {@category Tasks & Concurrency}
class LevitTaskCachePolicy<T> {
  /// Unique key for the cached result. If null, the task ID is used.
  final String? key;

  /// Time-to-live for the cached result.
  final Duration ttl;

  /// Function to serialize the task result to JSON.
  final Map<String, dynamic> Function(T value) toJson;

  /// Function to deserialize the task result from JSON.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Creates a caching policy.
  const LevitTaskCachePolicy({
    this.key,
    required this.ttl,
    required this.toJson,
    required this.fromJson,
  });
}

/// Represents the latest tracked execution of a logical task.
///
/// {@category Tasks & Concurrency}
class LevitTaskDetails {
  /// The current reactive status of the task.
  final LxStatus<dynamic> status;

  /// Unique admitted execution ID, when known.
  final String? executionId;

  /// Diagnostic path of the scheduling owner.
  final String ownerPath;

  /// Owning [LevitTaskGroup] ID, if any.
  final String? groupId;

  /// Parent [LevitTaskGroup] ID, if any.
  final String? parentGroupId;

  /// Effective absolute deadline, if any.
  final DateTime? deadline;

  /// Structured cancellation reason, when cancelled.
  final LevitTaskCancellationReason? cancellationReason;

  /// Current scheduling phase.
  final LevitTaskPhase phase;

  /// Stable task metadata.
  final LevitTaskMetadata metadata;

  /// Scheduling priority.
  final LevitTaskPriority priority;

  /// Current attempt number (`0` while queued before execution starts, then
  /// 1-based: `1`, `2`, ...).
  final int attempt;

  /// Terminal outcome, when complete.
  final LevitTaskOutcome? outcome;

  /// The weight used for aggregate progress.
  final double weight;

  /// Progress from `0.0` to `1.0`.
  final double progress;

  /// Whether the task has started executing.
  final bool started;

  /// Timestamp when this execution was queued, if known.
  final DateTime? queuedAt;

  /// Timestamp when this execution started, if started.
  final DateTime? startedAt;

  /// Timestamp when this execution reached a terminal state, if finished.
  final DateTime? finishedAt;

  /// Measured duration spent waiting in the queue, if available.
  final Duration? queueDuration;

  /// Measured duration spent running, if available.
  final Duration? runDuration;

  /// Creates task details.
  const LevitTaskDetails({
    required this.status,
    this.executionId,
    this.ownerPath = '?',
    this.groupId,
    this.parentGroupId,
    this.deadline,
    this.cancellationReason,
    this.phase = LevitTaskPhase.completed,
    this.metadata = LevitTaskMetadata.none,
    this.priority = LevitTaskPriority.normal,
    this.attempt = 0,
    this.outcome,
    this.weight = 1.0,
    this.progress = 0.0,
    this.started = false,
    this.queuedAt,
    this.startedAt,
    this.finishedAt,
    this.queueDuration,
    this.runDuration,
  });

  /// Creates a copy with selected fields replaced.
  LevitTaskDetails copyWith({
    LxStatus<dynamic>? status,
    String? executionId,
    String? ownerPath,
    String? groupId,
    String? parentGroupId,
    DateTime? deadline,
    LevitTaskCancellationReason? cancellationReason,
    LevitTaskPhase? phase,
    LevitTaskMetadata? metadata,
    LevitTaskPriority? priority,
    int? attempt,
    LevitTaskOutcome? outcome,
    double? weight,
    double? progress,
    bool? started,
    DateTime? queuedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    Duration? queueDuration,
    Duration? runDuration,
  }) {
    return LevitTaskDetails(
      status: status ?? this.status,
      executionId: executionId ?? this.executionId,
      ownerPath: ownerPath ?? this.ownerPath,
      groupId: groupId ?? this.groupId,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      deadline: deadline ?? this.deadline,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      phase: phase ?? this.phase,
      metadata: metadata ?? this.metadata,
      priority: priority ?? this.priority,
      attempt: attempt ?? this.attempt,
      outcome: outcome ?? this.outcome,
      weight: weight ?? this.weight,
      progress: progress ?? this.progress,
      started: started ?? this.started,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      queueDuration: queueDuration ?? this.queueDuration,
      runDuration: runDuration ?? this.runDuration,
    );
  }
}
