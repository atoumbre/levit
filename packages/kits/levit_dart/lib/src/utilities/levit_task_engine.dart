part of '../../levit_dart.dart';

/// A standalone engine for named, cancellable asynchronous work.
///
/// The engine provides global priority/concurrency scheduling while conflict
/// policies define ordering for submissions that share a logical task ID.
class LevitTaskEngine implements LevitDisposable {
  int _maxConcurrent;

  /// The maximum number of concurrent admitted executions.
  int get maxConcurrent => _maxConcurrent;

  set maxConcurrent(int value) {
    if (value < 1) {
      throw RangeError.range(value, 1, null, 'maxConcurrent');
    }
    _maxConcurrent = value;
    _schedulePump();
  }

  /// The cache provider used by this engine.
  LevitTaskCacheProvider cacheProvider;

  /// Optional global error handler for terminal task failures.
  void Function(Object error, StackTrace stackTrace)? onTaskError;

  /// Optional local lifecycle instrumentation callback.
  void Function(LevitTaskEvent event)? onTaskEvent;

  /// Diagnostic path attached to task events.
  String ownerPath;

  final Map<String, _TaskGroup> _groups = {};
  final Map<String, _TaskExecution> _executions = {};
  final Set<_TaskExecution> _activeExecutions = {};
  final Queue<_TaskExecution> _highPriorityQueue = Queue<_TaskExecution>();
  final Queue<_TaskExecution> _normalPriorityQueue = Queue<_TaskExecution>();
  final Queue<_TaskExecution> _lowPriorityQueue = Queue<_TaskExecution>();
  bool _pumpScheduled = false;
  bool _disposed = false;

  /// Creates a task engine with [maxConcurrent] workers.
  LevitTaskEngine({
    required int maxConcurrent,
    LevitTaskCacheProvider? cacheProvider,
    this.onTaskError,
    this.onTaskEvent,
    this.ownerPath = '?',
  })  : _maxConcurrent = maxConcurrent,
        cacheProvider = cacheProvider ?? InMemoryTaskCacheProvider() {
    if (maxConcurrent < 1) {
      throw RangeError.range(maxConcurrent, 1, null, 'maxConcurrent');
    }
  }

  static int _nextTaskId = 0;
  static int _nextExecutionId = 0;

  static String _generateTaskId() =>
      'task_${DateTime.now().microsecondsSinceEpoch}_${_nextTaskId++}';

  static String _generateExecutionId() =>
      'execution_${DateTime.now().microsecondsSinceEpoch}_'
      '${_nextExecutionId++}';

  static void _onTaskErrorUnset(Object error, StackTrace stackTrace) {}
  static void _onTaskEventUnset(LevitTaskEvent event) {}

  void _emitTaskEvent(LevitTaskEvent event) {
    try {
      _executions[event.executionId]?.config.onEvent?.call(event);
    } catch (_) {
      // Per-execution instrumentation must never affect application work.
    }
    try {
      onTaskEvent?.call(event);
    } catch (_) {
      // Instrumentation must never affect application work.
    }
    LevitTaskMiddleware._emit(event);
  }

  /// Schedules [task] and returns only its eventual result.
  ///
  /// Use [submit] when execution identity or per-execution cancellation is
  /// required. Cancellation, dropping, and superseding complete with `null`.
  Future<T?> schedule<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return submit<T>(
      task,
      id: id,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess: onSuccess,
      onProgress: onProgress,
      onCancel: onCancel,
      onEvent: onEvent,
      metadata: metadata,
      debugName: debugName,
    ).result;
  }

  /// Submits [task] and returns its execution identity and result.
  LevitTaskExecution<T> submit<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureUsable();
    if (retries < 0) throw RangeError.range(retries, 0, null, 'retries');
    if (retryDelay != null && retryDelay.isNegative) {
      throw ArgumentError.value(retryDelay, 'retryDelay');
    }

    final taskId = id ?? _generateTaskId();
    final taskMetadata = metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    final config = _TaskExecutionConfig(
      task: task,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess:
          onSuccess == null ? null : (dynamic value) => onSuccess(value as T),
      onProgress: onProgress,
      onCancel: onCancel,
      onEvent: onEvent,
      metadata: taskMetadata,
      runsInIsolate: false,
    );

    return _submitConfig<T>(
      taskId: taskId,
      config: config,
      conflictPolicy: conflictPolicy,
    );
  }

  /// Schedules a message-safe top-level/static [task] in a new isolate.
  Future<T?> scheduleIsolate<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return submitIsolate<I, T>(
      task,
      input,
      id: id,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess: onSuccess,
      onProgress: onProgress,
      onCancel: onCancel,
      onEvent: onEvent,
      metadata: metadata,
      debugName: debugName,
    ).result;
  }

  /// Submits a message-safe top-level/static [task] in a new isolate.
  LevitTaskExecution<T> submitIsolate<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureUsable();
    if (retries < 0) throw RangeError.range(retries, 0, null, 'retries');
    if (retryDelay != null && retryDelay.isNegative) {
      throw ArgumentError.value(retryDelay, 'retryDelay');
    }

    final taskId = id ?? _generateTaskId();
    final taskMetadata = metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    late _TaskExecution execution;
    final config = _TaskExecutionConfig(
      task: (context) => _runInTaskIsolate<I, T>(
        task: task,
        input: input,
        context: context,
        cancellation: execution.cancellation,
      ),
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess:
          onSuccess == null ? null : (dynamic value) => onSuccess(value as T),
      onProgress: onProgress,
      onCancel: onCancel,
      onEvent: onEvent,
      metadata: taskMetadata,
      runsInIsolate: true,
    );

    return _submitConfig<T>(
      taskId: taskId,
      config: config,
      conflictPolicy: conflictPolicy,
      captureExecution: (value) => execution = value,
    );
  }

  LevitTaskExecution<T> _submitConfig<T>({
    required String taskId,
    required _TaskExecutionConfig config,
    required TaskConflictPolicy conflictPolicy,
    void Function(_TaskExecution execution)? captureExecution,
  }) {
    var group = _groups[taskId];
    final existing = group?.latest;

    if (existing != null) {
      switch (conflictPolicy) {
        case TaskConflictPolicy.reject:
          final executionId = _generateExecutionId();
          final now = DateTime.now();
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.rejected,
            taskId: taskId,
            executionId: executionId,
            ownerPath: ownerPath,
            metadata: config.metadata,
            priority: config.priority,
            queuedAt: now,
            finishedAt: now,
            queueDuration: Duration.zero,
            runDuration: Duration.zero,
            outcome: LevitTaskOutcome.rejected,
            runsInIsolate: config.runsInIsolate,
          ));
          throw TaskConflictException(taskId);
        case TaskConflictPolicy.join:
          return _handleFor<T>(
            existing,
            LevitTaskSubmissionDisposition.joined,
          );
        case TaskConflictPolicy.drop:
          final executionId = _generateExecutionId();
          final now = DateTime.now();
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.skipped,
            taskId: taskId,
            executionId: executionId,
            ownerPath: ownerPath,
            metadata: config.metadata,
            priority: config.priority,
            queuedAt: now,
            finishedAt: now,
            queueDuration: Duration.zero,
            runDuration: Duration.zero,
            skipReason: TaskSkipReason.dropped,
            outcome: LevitTaskOutcome.dropped,
            runsInIsolate: config.runsInIsolate,
          ));
          return LevitTaskExecution<T>._(
            taskId: taskId,
            executionId: executionId,
            disposition: LevitTaskSubmissionDisposition.dropped,
            result: Future<T?>.value(),
            cancel: () {},
          );
        case TaskConflictPolicy.restart:
          _supersedeGroup(group!);
          group = _groups.putIfAbsent(taskId, () => _TaskGroup(taskId));
        case TaskConflictPolicy.enqueue:
          break;
        case TaskConflictPolicy.coalesceLatest:
          final tail = group!.coalescedTail;
          if (tail != null && tail.state == _TaskExecutionState.queued) {
            _moveQueuedExecution(tail, config.priority);
            tail.config = config;
            captureExecution?.call(tail);
            _emitTaskEvent(_eventFor(
              tail,
              type: LevitTaskEventType.coalesced,
              phase: LevitTaskPhase.queued,
            ));
            return _handleFor<T>(
              tail,
              LevitTaskSubmissionDisposition.coalesced,
            );
          }
      }
    }

    group ??= _groups.putIfAbsent(taskId, () => _TaskGroup(taskId));
    final execution = _TaskExecution(
      taskId: taskId,
      executionId: _generateExecutionId(),
      ownerPath: ownerPath,
      queuedAt: DateTime.now(),
      config: config,
    );
    captureExecution?.call(execution);
    group.outstanding.add(execution);
    _executions[execution.executionId] = execution;
    if (existing != null &&
        conflictPolicy == TaskConflictPolicy.coalesceLatest) {
      group.coalescedTail = execution;
    }
    _queueFor(execution.config.priority).add(execution);
    _emitTaskEvent(_eventFor(
      execution,
      type: LevitTaskEventType.queued,
      phase: LevitTaskPhase.queued,
    ));
    _processQueue();

    final disposition =
        existing != null && conflictPolicy == TaskConflictPolicy.restart
            ? LevitTaskSubmissionDisposition.restarted
            : LevitTaskSubmissionDisposition.admitted;
    return _handleFor<T>(execution, disposition);
  }

  LevitTaskExecution<T> _handleFor<T>(
    _TaskExecution execution,
    LevitTaskSubmissionDisposition disposition,
  ) {
    return LevitTaskExecution<T>._(
      taskId: execution.taskId,
      executionId: execution.executionId,
      disposition: disposition,
      result: execution.completer.future.then((value) => value as T?),
      cancel: () => cancelExecution(execution.executionId),
    );
  }

  Queue<_TaskExecution> _queueFor(TaskPriority priority) {
    return _queueForPriority(
      priority: priority,
      highPriorityQueue: _highPriorityQueue,
      normalPriorityQueue: _normalPriorityQueue,
      lowPriorityQueue: _lowPriorityQueue,
    );
  }

  void _moveQueuedExecution(
    _TaskExecution execution,
    TaskPriority nextPriority,
  ) {
    if (execution.config.priority == nextPriority) return;
    _queueFor(execution.config.priority).remove(execution);
    _queueFor(nextPriority).add(execution);
  }

  void _schedulePump() {
    if (_pumpScheduled || _disposed) return;
    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      _processQueue();
    });
  }

  void _processQueue() {
    if (_disposed) return;
    while (_activeExecutions.length < _maxConcurrent) {
      final execution = _takeNextEligible();
      if (execution == null) return;
      _start(execution);
    }
  }

  _TaskExecution? _takeNextEligible() {
    for (final queue in [
      _highPriorityQueue,
      _normalPriorityQueue,
      _lowPriorityQueue,
    ]) {
      for (final execution in queue) {
        if (_isEligible(execution)) {
          queue.remove(execution);
          return execution;
        }
      }
    }
    return null;
  }

  bool _isEligible(_TaskExecution execution) {
    if (execution.state != _TaskExecutionState.queued) return false;
    final group = _groups[execution.taskId];
    return group != null &&
        group.outstanding.isNotEmpty &&
        identical(group.outstanding.first, execution);
  }

  void _start(_TaskExecution execution) {
    execution.state = _TaskExecutionState.running;
    execution.startedAt = DateTime.now();
    final group = _groups[execution.taskId];
    if (identical(group?.coalescedTail, execution)) {
      group!.coalescedTail = null;
    }
    _activeExecutions.add(execution);
    unawaited(_run(execution));
  }

  Future<void> _run(_TaskExecution execution) async {
    final config = execution.config;

    try {
      final cachedResult = await _readCachedTaskResult<dynamic>(
        cacheProvider: cacheProvider,
        taskId: execution.taskId,
        cachePolicy: config.cachePolicy,
      );
      if (cachedResult != null) {
        try {
          config.onSuccess?.call(cachedResult.result);
        } catch (_) {
          // Result observers do not alter cached application work.
        }
        _completeValue(
          execution,
          cachedResult.result,
          eventType: LevitTaskEventType.skipped,
          outcome: LevitTaskOutcome.cacheHit,
          skipReason: TaskSkipReason.cacheHit,
        );
        return;
      }

      if (execution.cancellation.isCancelled) {
        _completeCancelled(
          execution,
          _cancellationReason(
            execution,
            TaskSkipReason.cancelledBeforeStart,
          ),
        );
        return;
      }

      config.onStart?.call();
      if (execution.cancellation.isCancelled) {
        _completeCancelled(
          execution,
          _cancellationReason(
            execution,
            TaskSkipReason.cancelledBeforeStart,
          ),
        );
        return;
      }

      while (true) {
        execution.attempt++;
        _emitTaskEvent(_eventFor(
          execution,
          type: LevitTaskEventType.started,
          phase: LevitTaskPhase.running,
        ));
        final context = LevitTaskContext._(
          taskId: execution.taskId,
          executionId: execution.executionId,
          attempt: execution.attempt,
          cancellation: execution.cancellation,
          reportProgress: (value) => _reportProgress(execution, value),
        );

        try {
          context.throwIfCancelled();
          final result = await config.task(context);
          if (execution.cancellation.isCancelled) {
            _completeCancelled(
              execution,
              _cancellationReason(
                execution,
                TaskSkipReason.cancelledAfterRun,
              ),
            );
            return;
          }

          await _writeCachedTaskResult<dynamic>(
            cacheProvider: cacheProvider,
            taskId: execution.taskId,
            cachePolicy: config.cachePolicy,
            result: result,
          );
          try {
            config.onSuccess?.call(result);
          } catch (_) {
            // Result observers do not alter successful application work.
          }
          _completeValue(
            execution,
            result,
            eventType: LevitTaskEventType.finished,
            outcome: LevitTaskOutcome.succeeded,
          );
          return;
        } catch (error, stackTrace) {
          if (execution.cancellation.isCancelled ||
              error is LevitTaskCancelledException) {
            _completeCancelled(
              execution,
              _cancellationReason(
                execution,
                TaskSkipReason.cancelledAfterRun,
              ),
              error: error,
              stackTrace: stackTrace,
            );
            return;
          }

          if (execution.attempt <= config.retries) {
            final baseDelay =
                config.retryDelay ?? const Duration(milliseconds: 500);
            final retryIn = config.useExponentialBackoff
                ? baseDelay * math.pow(2, execution.attempt - 1)
                : baseDelay;
            _emitTaskEvent(_eventFor(
              execution,
              type: LevitTaskEventType.retryScheduled,
              phase: LevitTaskPhase.retryWaiting,
              attempt: execution.attempt + 1,
              retryIn: retryIn,
              error: error,
              stackTrace: stackTrace,
            ));
            await Future.any<void>([
              Future<void>.delayed(retryIn),
              execution.cancellation.cancelled,
            ]);
            if (execution.cancellation.isCancelled) {
              _completeCancelled(
                execution,
                _cancellationReason(
                  execution,
                  TaskSkipReason.cancelledAfterRun,
                ),
                error: error,
                stackTrace: stackTrace,
              );
              return;
            }
            continue;
          }

          _completeError(execution, error, stackTrace);
          return;
        }
      }
    } catch (error, stackTrace) {
      if (execution.cancellation.isCancelled) {
        _completeCancelled(
          execution,
          _cancellationReason(
            execution,
            TaskSkipReason.cancelledAfterRun,
          ),
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        _completeError(execution, error, stackTrace);
      }
    }
  }

  void _reportProgress(_TaskExecution execution, double value) {
    if (execution.state != _TaskExecutionState.running ||
        execution.cancellation.isCancelled) {
      return;
    }
    execution.progress = value;
    try {
      execution.config.onProgress?.call(value);
    } catch (_) {
      // Progress observers are instrumentation and must remain isolated.
    }
    _emitTaskEvent(_eventFor(
      execution,
      type: LevitTaskEventType.progress,
      phase: LevitTaskPhase.running,
      progress: value,
    ));
  }

  void _completeValue(
    _TaskExecution execution,
    dynamic value, {
    required LevitTaskEventType eventType,
    required LevitTaskOutcome outcome,
    TaskSkipReason? skipReason,
  }) {
    final now = DateTime.now();
    _emitTaskEvent(_eventFor(
      execution,
      type: eventType,
      phase: LevitTaskPhase.completed,
      finishedAt: now,
      progress: outcome == LevitTaskOutcome.succeeded ? 1 : execution.progress,
      outcome: outcome,
      skipReason: skipReason,
    ));
    _finalize(execution);
    if (!execution.completer.isCompleted) execution.completer.complete(value);
  }

  void _completeError(
    _TaskExecution execution,
    Object error,
    StackTrace stackTrace,
  ) {
    Object deliveredError = error;
    StackTrace deliveredStack = stackTrace;
    final handler = execution.config.onError ?? onTaskError;
    if (handler != null) {
      try {
        handler(error, stackTrace);
      } catch (handlerError, handlerStack) {
        deliveredError = handlerError;
        deliveredStack = handlerStack;
      }
    }
    final now = DateTime.now();
    _emitTaskEvent(_eventFor(
      execution,
      type: LevitTaskEventType.failed,
      phase: LevitTaskPhase.completed,
      finishedAt: now,
      outcome: LevitTaskOutcome.failed,
      error: error,
      stackTrace: stackTrace,
    ));
    _finalize(execution);
    if (!execution.completer.isCompleted) {
      execution.completer.completeError(deliveredError, deliveredStack);
    }
  }

  void _completeCancelled(
    _TaskExecution execution,
    TaskSkipReason reason, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    try {
      execution.config.onCancel?.call();
    } catch (_) {
      // Cancellation observers do not change cancellation semantics.
    }
    final outcome = reason == TaskSkipReason.superseded
        ? LevitTaskOutcome.superseded
        : LevitTaskOutcome.cancelled;
    final now = DateTime.now();
    _emitTaskEvent(_eventFor(
      execution,
      type: LevitTaskEventType.skipped,
      phase: LevitTaskPhase.completed,
      finishedAt: now,
      outcome: outcome,
      skipReason: reason,
      error: error,
      stackTrace: stackTrace,
    ));
    _finalize(execution);
    if (!execution.completer.isCompleted) execution.completer.complete(null);
  }

  TaskSkipReason _cancellationReason(
    _TaskExecution execution,
    TaskSkipReason fallback,
  ) {
    return execution.cancellationReason == TaskSkipReason.superseded
        ? TaskSkipReason.superseded
        : fallback;
  }

  void _finalize(_TaskExecution execution) {
    if (execution.state == _TaskExecutionState.completed) return;
    execution.state = _TaskExecutionState.completed;
    _activeExecutions.remove(execution);
    _executions.remove(execution.executionId);
    final group = _groups[execution.taskId];
    group?.outstanding.remove(execution);
    if (identical(group?.coalescedTail, execution)) {
      group!.coalescedTail = null;
    }
    if (group != null && group.outstanding.isEmpty) {
      _groups.remove(execution.taskId);
    }
    _schedulePump();
  }

  LevitTaskEvent _eventFor(
    _TaskExecution execution, {
    required LevitTaskEventType type,
    required LevitTaskPhase phase,
    int? attempt,
    DateTime? finishedAt,
    Duration? retryIn,
    double? progress,
    TaskSkipReason? skipReason,
    LevitTaskOutcome? outcome,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final startedAt = execution.startedAt;
    final end = finishedAt;
    return LevitTaskEvent(
      type: type,
      taskId: execution.taskId,
      executionId: execution.executionId,
      ownerPath: execution.ownerPath,
      phase: phase,
      metadata: execution.config.metadata,
      priority: execution.config.priority,
      attempt: attempt ?? execution.attempt,
      maxRetries: execution.config.retries,
      queuedAt: execution.queuedAt,
      startedAt: startedAt,
      finishedAt: end,
      queueDuration:
          startedAt == null ? null : startedAt.difference(execution.queuedAt),
      runDuration:
          end == null || startedAt == null ? null : end.difference(startedAt),
      retryIn: retryIn,
      progress: progress,
      skipReason: skipReason,
      outcome: outcome,
      error: error,
      stackTrace: stackTrace,
      runsInIsolate: execution.config.runsInIsolate,
    );
  }

  /// Reports progress for the latest running execution of logical [id].
  void updateProgress(String id, double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw RangeError.range(progress, 0, 1, 'progress');
    }
    final candidates = _activeExecutions.where((item) => item.taskId == id);
    if (candidates.isEmpty) return;
    _reportProgress(candidates.last, progress);
  }

  /// Dynamically updates engine configuration.
  void config({
    int? maxConcurrent,
    LevitTaskCacheProvider? cacheProvider,
    String? ownerPath,
    void Function(Object error, StackTrace stackTrace)? onTaskError =
        _onTaskErrorUnset,
    void Function(LevitTaskEvent event)? onTaskEvent = _onTaskEventUnset,
  }) {
    if (maxConcurrent != null) this.maxConcurrent = maxConcurrent;
    if (cacheProvider != null) this.cacheProvider = cacheProvider;
    if (ownerPath != null) this.ownerPath = ownerPath;
    if (!identical(onTaskError, _onTaskErrorUnset)) {
      this.onTaskError = onTaskError;
    }
    if (!identical(onTaskEvent, _onTaskEventUnset)) {
      this.onTaskEvent = onTaskEvent;
    }
  }

  /// Cooperatively cancels all outstanding executions for logical [id].
  void cancel(String id) {
    final matches = _executions.values
        .where((execution) => execution.taskId == id)
        .toList(growable: false);
    for (final execution in matches) {
      _cancelExecution(execution, TaskSkipReason.cancelledWhileQueued);
    }
  }

  /// Cooperatively cancels one admitted execution.
  bool cancelExecution(String executionId) {
    final execution = _executions[executionId];
    if (execution == null) return false;
    _cancelExecution(execution, TaskSkipReason.cancelledWhileQueued);
    return true;
  }

  void _cancelExecution(
    _TaskExecution execution,
    TaskSkipReason queuedReason,
  ) {
    if (execution.state == _TaskExecutionState.completed) return;
    execution.cancellationReason = queuedReason;
    execution.cancellation.cancel();
    if (execution.state == _TaskExecutionState.queued) {
      _queueFor(execution.config.priority).remove(execution);
      _completeCancelled(execution, queuedReason);
    }
  }

  void _supersedeGroup(_TaskGroup group) {
    final previous = List<_TaskExecution>.of(group.outstanding);
    group.outstanding.clear();
    group.coalescedTail = null;
    _groups.remove(group.taskId);
    for (final execution in previous) {
      execution.detachedByRestart = true;
      _cancelExecution(execution, TaskSkipReason.superseded);
    }
  }

  /// Cooperatively cancels every outstanding execution.
  void cancelAll() {
    for (final execution
        in List<_TaskExecution>.of(_executions.values, growable: false)) {
      _cancelExecution(execution, TaskSkipReason.cancelledWhileQueued);
    }
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('LevitTaskEngine is disposed.');
  }

  @override
  void dispose() {
    if (_disposed) return;
    cancelAll();
    _disposed = true;
  }
}

Future<T> _runInTaskIsolate<I, T>({
  required LevitIsolateTask<I, T> task,
  required I input,
  required LevitTaskContext context,
  required _LevitTaskCancellation cancellation,
}) async {
  final events = ReceivePort();
  final errors = ReceivePort();
  final exits = ReceivePort();
  final result = Completer<T>();
  SendPort? cancellationPort;

  void sendCancellation() => cancellationPort?.send(null);
  if (cancellation.isCancelled) sendCancellation();
  unawaited(cancellation.cancelled.then((_) => sendCancellation()));

  late final StreamSubscription<dynamic> eventSubscription;
  late final StreamSubscription<dynamic> errorSubscription;
  late final StreamSubscription<dynamic> exitSubscription;

  void completeError(Object error, StackTrace stackTrace) {
    if (!result.isCompleted) result.completeError(error, stackTrace);
  }

  eventSubscription = events.listen((dynamic raw) {
    final message = raw as (Object, Object?);
    switch (message.$1) {
      case _IsolateTaskMessage.cancellationPort:
        cancellationPort = message.$2! as SendPort;
        if (cancellation.isCancelled) sendCancellation();
      case _IsolateTaskMessage.progress:
        if (!cancellation.isCancelled) {
          context.reportProgress(message.$2! as double);
        }
      case _IsolateTaskMessage.success:
        if (!result.isCompleted) result.complete(message.$2 as T);
      case _IsolateTaskMessage.error:
        final errorParts = message.$2! as (String, String);
        completeError(
          RemoteError(errorParts.$1, errorParts.$2),
          StackTrace.fromString(errorParts.$2),
        );
    }
  });
  errorSubscription = errors.listen((dynamic raw) {
    final parts = raw as List<dynamic>;
    completeError(
      RemoteError(parts[0] as String, parts[1] as String),
      StackTrace.fromString(parts[1] as String),
    );
  });
  exitSubscription = exits.listen((_) {
    if (!result.isCompleted) {
      completeError(
        StateError('Task isolate exited without a result.'),
        StackTrace.current,
      );
    }
  });

  try {
    await Isolate.spawn<List<Object?>>(
      _levitTaskIsolateEntry,
      <Object?>[
        task,
        input,
        events.sendPort,
        context.taskId,
        context.executionId,
        context.attempt,
      ],
      onError: errors.sendPort,
      onExit: exits.sendPort,
      errorsAreFatal: true,
      debugName: context.executionId,
    );
    return await result.future;
  } finally {
    await eventSubscription.cancel();
    await errorSubscription.cancel();
    await exitSubscription.cancel();
    events.close();
    errors.close();
    exits.close();
  }
}

void _levitTaskIsolateEntry(List<Object?> message) async {
  final task = message[0] as Function;
  final input = message[1];
  final eventPort = message[2]! as SendPort;
  final taskId = message[3]! as String;
  final executionId = message[4]! as String;
  final attempt = message[5]! as int;
  final cancellationPort = ReceivePort();
  final context = LevitIsolateTaskContext._(
    taskId: taskId,
    executionId: executionId,
    attempt: attempt,
    cancellationPort: cancellationPort,
    eventPort: eventPort,
  );
  eventPort.send((
    _IsolateTaskMessage.cancellationPort,
    cancellationPort.sendPort,
  ));

  try {
    final result = await Function.apply(task, [input, context]);
    context.throwIfCancelled();
    eventPort.send((_IsolateTaskMessage.success, result));
  } catch (error, stackTrace) {
    eventPort.send((
      _IsolateTaskMessage.error,
      (error.toString(), stackTrace.toString()),
    ));
  } finally {
    context._close();
  }
}
