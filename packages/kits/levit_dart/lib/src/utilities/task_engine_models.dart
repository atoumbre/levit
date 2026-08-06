part of '../../levit_dart.dart';

/// Priority levels for task execution.
enum TaskPriority {
  /// High priority tasks are processed before normal tasks.
  high,

  /// Default priority for tasks.
  normal,

  /// Low priority tasks are processed after other tasks.
  low,
}

/// Defines what happens when a logical task ID already has pending work.
enum TaskConflictPolicy {
  /// Reject the new submission with [TaskConflictException].
  reject,

  /// Return the result of the latest outstanding execution.
  join,

  /// Ignore the new submission and complete it with `null`.
  drop,

  /// Cooperatively cancel outstanding work and admit the replacement.
  restart,

  /// Run every submission in FIFO order for the same logical task ID.
  enqueue,

  /// Retain one trailing execution and replace it with the latest submission.
  coalesceLatest,
}

/// The scheduling phase represented by a [LevitTaskEvent].
enum LevitTaskPhase {
  queued,
  running,
  retryWaiting,
  completed,
}

/// Terminal outcomes for task executions and rejected submissions.
enum LevitTaskOutcome {
  succeeded,
  failed,
  cancelled,
  superseded,
  dropped,
  rejected,
  cacheHit,
}

/// Lifecycle event types emitted by [LevitTaskEngine].
enum LevitTaskEventType {
  queued,
  started,
  progress,
  retryScheduled,
  finished,
  failed,
  skipped,
  rejected,
  coalesced,
}

/// Reasons why a task execution was skipped.
enum TaskSkipReason {
  cacheHit,
  cancelledWhileQueued,
  cancelledBeforeStart,
  cancelledAfterRun,
  superseded,
  dropped,
}

/// Describes a logical task conflict rejected by the engine.
class TaskConflictException implements Exception {
  /// The logical ID that already has outstanding work.
  final String taskId;

  /// Creates a conflict exception for [taskId].
  const TaskConflictException(this.taskId);

  @override
  String toString() =>
      'TaskConflictException: task "$taskId" already has outstanding work.';
}

/// Thrown by [LevitTaskContext.throwIfCancelled] after cancellation.
class LevitTaskCancelledException implements Exception {
  /// The logical task ID.
  final String taskId;

  /// The unique execution ID.
  final String executionId;

  /// Creates a cooperative cancellation exception.
  const LevitTaskCancelledException(this.taskId, this.executionId);

  @override
  String toString() => 'LevitTaskCancelledException: execution "$executionId" '
      'for task "$taskId" was cancelled.';
}

/// Stable, low-cardinality metadata attached to task executions.
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
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _isCancelled;
  Future<void> get cancelled => _cancelled.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled.complete();
  }
}

/// Context passed to every task attempt.
class LevitTaskContext {
  /// The stable logical task ID.
  final String taskId;

  /// A unique ID for this admitted execution.
  final String executionId;

  /// The one-based attempt number.
  final int attempt;

  final _LevitTaskCancellation _cancellation;
  final void Function(double value) _reportProgress;

  LevitTaskContext._({
    required this.taskId,
    required this.executionId,
    required this.attempt,
    required _LevitTaskCancellation cancellation,
    required void Function(double value) reportProgress,
  })  : _cancellation = cancellation,
        _reportProgress = reportProgress;

  /// Whether cooperative cancellation has been requested.
  bool get isCancelled => _cancellation.isCancelled;

  /// Completes when cooperative cancellation is requested.
  Future<void> get cancelled => _cancellation.cancelled;

  /// Throws [LevitTaskCancelledException] when cancellation was requested.
  void throwIfCancelled() {
    if (isCancelled) {
      throw LevitTaskCancelledException(taskId, executionId);
    }
  }

  /// Reports progress in the inclusive `0.0` to `1.0` range.
  void reportProgress(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
    throwIfCancelled();
    _reportProgress(value);
  }
}

/// Message-safe context provided inside a task isolate.
class LevitIsolateTaskContext {
  /// The stable logical task ID.
  final String taskId;

  /// A unique ID for this admitted execution.
  final String executionId;

  /// The one-based attempt number.
  final int attempt;

  final ReceivePort _cancellationPort;
  final SendPort _eventPort;
  bool _isCancelled = false;
  final Completer<void> _cancelled = Completer<void>();

  LevitIsolateTaskContext._({
    required this.taskId,
    required this.executionId,
    required this.attempt,
    required ReceivePort cancellationPort,
    required SendPort eventPort,
  })  : _cancellationPort = cancellationPort,
        _eventPort = eventPort {
    _cancellationPort.listen((_) {
      if (_isCancelled) return;
      _isCancelled = true;
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
      throw LevitTaskCancelledException(taskId, executionId);
    }
  }

  /// Reports progress in the inclusive `0.0` to `1.0` range.
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
typedef LevitIsolateTask<I, T> = FutureOr<T> Function(
  I input,
  LevitIsolateTaskContext context,
);

/// Structured lifecycle event emitted by [LevitTaskEngine].
class LevitTaskEvent {
  final LevitTaskEventType type;

  /// Stable logical task ID.
  final String taskId;

  /// Unique admitted execution ID.
  final String executionId;

  /// Diagnostic path of the owner that scheduled the execution.
  final String ownerPath;

  final LevitTaskPhase phase;
  final LevitTaskMetadata metadata;
  final TaskPriority priority;
  final int attempt;
  final int maxRetries;
  final DateTime timestamp;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Duration? queueDuration;
  final Duration? runDuration;
  final Duration? retryIn;
  final double? progress;
  final TaskSkipReason? skipReason;
  final LevitTaskOutcome? outcome;
  final Object? error;
  final StackTrace? stackTrace;
  final bool runsInIsolate;

  /// Compatibility view of [LevitTaskMetadata.debugName].
  String? get debugName => metadata.debugName;

  /// Compatibility alias for [runsInIsolate].
  bool get runInIsolate => runsInIsolate;

  LevitTaskEvent({
    required this.type,
    required this.taskId,
    String? executionId,
    this.ownerPath = '?',
    LevitTaskPhase? phase,
    LevitTaskMetadata? metadata,
    this.priority = TaskPriority.normal,
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
  })  : executionId = executionId ?? taskId,
        phase = phase ?? _phaseForEvent(type),
        metadata = metadata ??
            (debugName == null
                ? LevitTaskMetadata.none
                : LevitTaskMetadata(debugName: debugName)),
        runsInIsolate = runsInIsolate ?? runInIsolate ?? false,
        timestamp = timestamp ?? DateTime.now(),
        queuedAt = queuedAt ?? timestamp ?? DateTime.now();

  static LevitTaskPhase _phaseForEvent(LevitTaskEventType type) {
    return switch (type) {
      LevitTaskEventType.queued ||
      LevitTaskEventType.coalesced =>
        LevitTaskPhase.queued,
      LevitTaskEventType.started ||
      LevitTaskEventType.progress =>
        LevitTaskPhase.running,
      LevitTaskEventType.retryScheduled => LevitTaskPhase.retryWaiting,
      LevitTaskEventType.finished ||
      LevitTaskEventType.failed ||
      LevitTaskEventType.skipped ||
      LevitTaskEventType.rejected =>
        LevitTaskPhase.completed,
    };
  }
}

/// Receives task events from every [LevitTaskEngine] in this isolate.
abstract class LevitTaskMiddleware {
  /// Creates a task middleware.
  const LevitTaskMiddleware();

  static final List<LevitTaskMiddleware> _middlewares = [];
  static final Map<Object, LevitTaskMiddleware> _middlewaresByToken = {};

  /// Handles one structured task event.
  void onTaskEvent(LevitTaskEvent event);

  /// Registers [middleware] globally, optionally replacing the same [token].
  static T add<T extends LevitTaskMiddleware>(
    T middleware, {
    Object? token,
  }) {
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
    _middlewaresByToken
        .removeWhere((_, current) => identical(current, middleware));
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
    for (final middleware
        in List<LevitTaskMiddleware>.of(_middlewares, growable: false)) {
      try {
        middleware.onTaskEvent(event);
      } catch (_) {
        // Instrumentation is isolated from application work by design.
      }
    }
  }
}

/// How a submitted task related to existing work.
enum LevitTaskSubmissionDisposition {
  admitted,
  joined,
  dropped,
  restarted,
  coalesced,
}

/// A lightweight handle for one scheduled or joined execution.
class LevitTaskExecution<T> {
  /// Stable logical task ID.
  final String taskId;

  /// Unique admitted execution ID.
  final String executionId;

  /// How this submission was handled.
  final LevitTaskSubmissionDisposition disposition;

  /// The eventual result. Cancellation, dropping, and superseding yield `null`.
  final Future<T?> result;

  final void Function() _cancel;

  const LevitTaskExecution._({
    required this.taskId,
    required this.executionId,
    required this.disposition,
    required this.result,
    required void Function() cancel,
  }) : _cancel = cancel;

  /// Cooperatively cancels this execution.
  void cancel() => _cancel();
}

/// A dependency-free summary retained by [LevitTaskTracker].
class LevitTaskExecutionSummary {
  final String taskId;
  final String executionId;
  final String ownerPath;
  final LevitTaskPhase phase;
  final LevitTaskMetadata metadata;
  final TaskPriority priority;
  final int attempt;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Duration? queueDuration;
  final Duration? runDuration;
  final double progress;
  final LevitTaskOutcome? outcome;
  final Object? error;
  final StackTrace? stackTrace;

  const LevitTaskExecutionSummary({
    required this.taskId,
    required this.executionId,
    required this.ownerPath,
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

  factory LevitTaskExecutionSummary.fromEvent(LevitTaskEvent event) {
    return LevitTaskExecutionSummary(
      taskId: event.taskId,
      executionId: event.executionId,
      ownerPath: event.ownerPath,
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

  LevitTaskExecutionSummary apply(LevitTaskEvent event) {
    return LevitTaskExecutionSummary(
      taskId: taskId,
      executionId: executionId,
      ownerPath: event.ownerPath,
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
class LevitTaskTracker extends LevitTaskMiddleware implements LevitDisposable {
  /// Maximum number of terminal summaries retained.
  final int maxHistory;

  /// Summaries keyed by execution ID.
  final executions =
      LxMap<String, LevitTaskExecutionSummary>().named('taskExecutions');

  late final LxComputed<bool> hasBlockingTasks = (() {
    return executions.values.any(
      (summary) =>
          summary.phase != LevitTaskPhase.completed &&
          summary.metadata.blocksUserInteraction,
    );
  }).lx.named('hasBlockingTasks');

  bool _attached = false;
  bool _disposed = false;

  /// Creates a detached tracker.
  LevitTaskTracker({this.maxHistory = 100}) {
    if (maxHistory < 0) {
      throw RangeError.range(maxHistory, 0, null, 'maxHistory');
    }
  }

  /// Registers this tracker as global task middleware.
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
    executions[event.executionId] = current == null
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

/// Interface for persistent task result caching.
abstract class LevitTaskCacheProvider {
  /// Base constructor.
  const LevitTaskCacheProvider();

  /// Writes [data] to the cache under [key].
  Future<void> write(String key, Map<String, dynamic> data);

  /// Reads cached data for [key]. Returns `null` if not found.
  Future<Map<String, dynamic>?> read(String key);

  /// Deletes cached data for [key].
  Future<void> delete(String key);
}

/// A default in-memory implementation of [LevitTaskCacheProvider].
class InMemoryTaskCacheProvider implements LevitTaskCacheProvider {
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
class TaskCachePolicy<T> {
  /// Unique key for the cached result. If null, the task ID is used.
  final String? key;

  /// Time-to-live for the cached result.
  final Duration ttl;

  /// Function to serialize the task result to JSON.
  final Map<String, dynamic> Function(T value) toJson;

  /// Function to deserialize the task result from JSON.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Creates a caching policy.
  const TaskCachePolicy({
    this.key,
    required this.ttl,
    required this.toJson,
    required this.fromJson,
  });
}

/// Represents the latest tracked execution of a logical task.
class TaskDetails {
  /// The current reactive status of the task.
  final LxStatus<dynamic> status;

  /// Unique admitted execution ID, when known.
  final String? executionId;

  /// Diagnostic path of the scheduling owner.
  final String ownerPath;

  /// Current scheduling phase.
  final LevitTaskPhase phase;

  /// Stable task metadata.
  final LevitTaskMetadata metadata;

  /// Scheduling priority.
  final TaskPriority priority;

  /// Current one-based attempt number.
  final int attempt;

  /// Terminal outcome, when complete.
  final LevitTaskOutcome? outcome;

  /// The weight used for aggregate progress.
  final double weight;

  /// Progress from `0.0` to `1.0`.
  final double progress;

  /// Whether the task has started executing.
  final bool started;

  final DateTime? queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Duration? queueDuration;
  final Duration? runDuration;

  /// Creates task details.
  const TaskDetails({
    required this.status,
    this.executionId,
    this.ownerPath = '?',
    this.phase = LevitTaskPhase.completed,
    this.metadata = LevitTaskMetadata.none,
    this.priority = TaskPriority.normal,
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
  TaskDetails copyWith({
    LxStatus<dynamic>? status,
    String? executionId,
    String? ownerPath,
    LevitTaskPhase? phase,
    LevitTaskMetadata? metadata,
    TaskPriority? priority,
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
    return TaskDetails(
      status: status ?? this.status,
      executionId: executionId ?? this.executionId,
      ownerPath: ownerPath ?? this.ownerPath,
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
