part of '../kit_library.dart';

/// A standalone engine for named, prioritized, cancellable asynchronous work.
///
/// Provides weighted fair priority scheduling (`4 high : 2 normal : 1 low`),
/// bounded concurrency, structured concurrency via [rootGroup], cooperative
/// cancellation, retries, caching, and isolate execution. Conflict policies
/// ([LevitTaskConflictPolicy]) define ordering for submissions that share a
/// logical task ID.
///
/// Always own this engine in a controller via `own(...)` or await [dispose]
/// when done; disposal waits cooperatively for active runners to finish.
///
/// ```dart
/// final engine = LevitTaskEngine(maxConcurrent: 4);
/// final execution = engine.submit<String>(
///   (ctx) async {
///     ctx.reportProgress(0.5);
///     ctx.throwIfCancelled();
///     return await fetchReport();
///   },
///   id: 'report',
///   conflictPolicy: LevitTaskConflictPolicy.restart,
/// );
/// final outcome = await execution.outcome;
/// await engine.dispose();
/// ```
///
/// {@category Tasks & Concurrency}
class LevitTaskEngine
    implements LevitDisposable, LevitDrainable, LevitExecutionBoundary {
  final Set<Future<void>> _runners = {};
  Future<void>? _disposeFuture;
  final List<LevitDisposalFailure> _cleanupFailures = [];

  int _maxConcurrent;

  /// Maximum number of queued leaf entries before new admissions throw
  /// [LevitTaskQueueFullException].
  ///
  /// `null` explicitly opts into an unbounded queue; defaults to `256`.
  final int? maxPending;

  /// The root supervisor [LevitTaskGroup] owning all top-level tasks and child
  /// groups submitted to this engine.
  late final LevitTaskGroup rootGroup = LevitTaskGroup._(
    this,
    null,
    name: 'root',
    policy: LevitTaskGroupPolicy.supervisor,
    root: true,
  );
  LxVar<LevitTaskTreeSnapshot>? _taskTree;

  /// Lazy reactive snapshot of this engine's structured task-group tree.
  ///
  /// Closed automatically when this engine is disposed.
  LxReadable<LevitTaskTreeSnapshot> get taskTree =>
      _taskTree ??= LxVar(LevitTaskTreeSnapshot._(rootGroup));
  int _pendingCount = 0;

  /// Number of queued leaf entries; joined and coalesced replacements share
  /// their underlying queue entry.
  int get pendingCount => _pendingCount;

  /// Number of task executions currently running.
  int get runningCount => _activeExecutions.length;
  int _priorityCursor = 0;
  static const _priorityCycle = [
    LevitTaskPriority.high,
    LevitTaskPriority.high,
    LevitTaskPriority.high,
    LevitTaskPriority.high,
    LevitTaskPriority.normal,
    LevitTaskPriority.normal,
    LevitTaskPriority.low,
  ];

  void _notifyTaskTree() {
    final tree = _taskTree;
    if (tree != null && !tree.isDisposed)
      tree.value = LevitTaskTreeSnapshot._(rootGroup);
  }

  LevitTaskGroup _resolveGroup(LevitTaskGroup? group) {
    final resolved =
        group ??
        (identical(LevitTaskGroup.current?.engine, this)
            ? LevitTaskGroup.current
            : null) ??
        rootGroup;
    if (!identical(resolved.engine, this))
      throw ArgumentError('Group belongs to another engine.');
    resolved._ensureAdmission();
    return resolved;
  }

  /// The maximum number of concurrent admitted executions.
  ///
  /// Setting a new value immediately schedules the queue pump to admit queued
  /// work. Throws a [RangeError] if set to a value less than `1`.
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

  /// Optional default error handler for terminal task failures.
  void Function(Object error, StackTrace stackTrace)? onTaskError;

  /// Optional local lifecycle instrumentation callback.
  void Function(LevitTaskEvent event)? onTaskEvent;

  /// Diagnostic path attached to task events.
  String ownerPath;

  final Map<Object, _TaskGroup> _groups = {};
  final Map<String, _TaskExecution> _executions = {};
  final Set<_TaskExecution> _activeExecutions = {};
  final Queue<_TaskExecution> _highPriorityQueue = Queue<_TaskExecution>();
  final Queue<_TaskExecution> _normalPriorityQueue = Queue<_TaskExecution>();
  final Queue<_TaskExecution> _lowPriorityQueue = Queue<_TaskExecution>();
  bool _pumpScheduled = false;
  bool _disposed = false;

  /// Creates a task engine with [maxConcurrent] worker slots.
  ///
  /// * [maxConcurrent]: Maximum simultaneous executions (must be >= 1).
  /// * [maxPending]: Queue capacity limit (defaults to `256`; `null` for
  ///   unbounded; must be >= 1 when non-null).
  /// * [cacheProvider]: Cache backend; defaults to
  ///   [LevitTaskCacheProvider.inMemory].
  /// * [onTaskError]: Optional fallback handler for terminal task errors.
  /// * [onTaskEvent]: Optional observer for all [LevitTaskEvent]s emitted by
  ///   this engine.
  /// * [ownerPath]: Diagnostic owner label attached to events (defaults to `'?'`).
  ///
  /// Throws a [RangeError] if [maxConcurrent] < 1 or [maxPending] < 1.
  LevitTaskEngine({
    required int maxConcurrent,
    this.maxPending = 256,
    LevitTaskCacheProvider? cacheProvider,
    this.onTaskError,
    this.onTaskEvent,
    this.ownerPath = '?',
  }) : _maxConcurrent = maxConcurrent,
       cacheProvider = cacheProvider ?? LevitTaskCacheProvider.inMemory() {
    if (maxConcurrent < 1) {
      throw RangeError.range(maxConcurrent, 1, null, 'maxConcurrent');
    }
    if (maxPending != null && maxPending! < 1)
      throw RangeError.value(maxPending!, 'maxPending');
  }

  static int _nextTaskId = 0;
  static int _nextExecutionId = 0;
  static final String _idPrefix = DateTime.now().microsecondsSinceEpoch
      .toRadixString(36);

  static String _generateTaskId() => 'task_${_idPrefix}_${_nextTaskId++}';

  static String _generateExecutionId() =>
      'execution_${_idPrefix}_${_nextExecutionId++}';

  static void _onTaskErrorUnset(Object error, StackTrace stackTrace) {}
  static void _onTaskEventUnset(LevitTaskEvent event) {}

  void _emitTaskEvent(
    LevitTaskEvent? event, {
    void Function(LevitTaskEvent)? onEvent,
  }) {
    if (event == null) return;
    try {
      final callback =
          onEvent ?? _executions[event.executionId]?.config.onEvent;
      callback?.call(event);
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

  /// Schedules [task] and returns its eventual result [Future].
  ///
  /// Shorthand for `submit(...).result`. Use [submit] when you need execution
  /// identity, per-execution cancellation, or a non-throwing [LevitTaskResult]
  /// via [LevitTaskExecution.outcome].
  ///
  /// Throws [LevitTaskConflictException] synchronously under
  /// [LevitTaskConflictPolicy.reject], [LevitTaskQueueFullException] when
  /// [maxPending] is exceeded, or [StateError] when disposed. Cancellation,
  /// dropping, and superseding reject the returned [Future] with
  /// [LevitTaskCancelledException], [LevitTaskDroppedException], or
  /// [LevitTaskSupersededException].
  Future<T> schedule<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    void Function(Object, StackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
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
      retryPolicy: retryPolicy,
      group: group,
      deadline: deadline,
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

  /// Submits [task] and returns a [LevitTaskExecution] handle exposing
  /// execution identity, [LevitTaskExecution.result],
  /// [LevitTaskExecution.outcome], and cooperative [LevitTaskExecution.cancel].
  ///
  /// * [id]: Logical task ID used for conflict handling and cancellation;
  ///   auto-generated when omitted.
  /// * [priority]: Scheduling priority (defaults to [LevitTaskPriority.normal]).
  /// * [conflictPolicy]: Behavior when [id] already has outstanding work
  ///   (defaults to [LevitTaskConflictPolicy.reject]).
  /// * [retryPolicy]: Optional retry schedule for failures.
  /// * [group]: Owning [LevitTaskGroup] (defaults to the active group on this
  ///   engine, or [rootGroup]).
  /// * [deadline]: Optional absolute deadline, clamped to [group]'s deadline.
  /// * [onError] / [onStart] / [onSuccess] / [onProgress] / [onCancel] / [onEvent]:
  ///   Optional per-execution lifecycle callbacks.
  /// * [cachePolicy]: Optional caching configuration using [cacheProvider].
  /// * [metadata]: Structured task metadata; overrides [debugName] if both are
  ///   provided.
  /// * [debugName]: Convenience label when [metadata] is omitted.
  LevitTaskExecution<T> submit<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    void Function(Object, StackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureUsable();

    final taskId = id ?? _generateTaskId();
    final taskMetadata =
        metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    final resolvedGroup = _resolveGroup(group);
    final config = _TaskExecutionConfig(
      task: task,
      priority: priority,
      retryPolicy: retryPolicy,
      group: resolvedGroup,
      deadline: _earliestDeadline(deadline, resolvedGroup.deadline),
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess: onSuccess == null
          ? null
          : (dynamic value) => onSuccess(value as T),
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

  /// Schedules a top-level or static [task] in a spawned `Isolate` and returns
  /// its eventual result [Future].
  ///
  /// Both [input] and the returned [T] must be sendable across isolate
  /// boundaries. Shorthand for `submitIsolate(...).result`.
  Future<T> scheduleIsolate<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    void Function(Object, StackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
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
      retryPolicy: retryPolicy,
      group: group,
      deadline: deadline,
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

  /// Submits a top-level or static [task] to run in a spawned `Isolate` and
  /// returns its [LevitTaskExecution] handle.
  ///
  /// [task] must be a top-level function or static method, and both [input] and
  /// the returned [T] must be sendable across isolate boundaries. See [submit]
  /// for parameter semantics.
  LevitTaskExecution<T> submitIsolate<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    void Function(Object, StackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    void Function(LevitTaskEvent event)? onEvent,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureUsable();

    final taskId = id ?? _generateTaskId();
    final taskMetadata =
        metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    late _TaskExecution execution;
    final resolvedGroup = _resolveGroup(group);
    final config = _TaskExecutionConfig(
      task: (context) => _runInTaskIsolate<I, T>(
        task: task,
        input: input,
        context: context,
        cancellation: execution.cancellation,
      ),
      priority: priority,
      retryPolicy: retryPolicy,
      group: resolvedGroup,
      deadline: _earliestDeadline(deadline, resolvedGroup.deadline),
      onError: onError,
      cachePolicy: cachePolicy,
      onStart: onStart,
      onSuccess: onSuccess == null
          ? null
          : (dynamic value) => onSuccess(value as T),
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
    required LevitTaskConflictPolicy conflictPolicy,
    void Function(_TaskExecution execution)? captureExecution,
  }) {
    // Root work needs no composite identity. Child keys are typed records, so
    // arbitrary user task IDs cannot collide across ownership boundaries.
    final Object schedulingKey = config.group._root
        ? taskId
        : (config.group, taskId);
    var group = _groups[schedulingKey];
    final existing = group?.latest;

    if (existing != null) {
      switch (conflictPolicy) {
        case LevitTaskConflictPolicy.reject:
          final executionId = _generateExecutionId();
          final now = DateTime.now();
          _emitTaskEvent(
            LevitTaskEvent(
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
            ),
          );
          throw LevitTaskConflictException(taskId);
        case LevitTaskConflictPolicy.join:
          return _handleFor<T>(existing, LevitTaskSubmissionDisposition.joined);
        case LevitTaskConflictPolicy.drop:
          final executionId = _generateExecutionId();
          final now = DateTime.now();
          _emitTaskEvent(
            LevitTaskEvent(
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
              skipReason: LevitTaskSkipReason.dropped,
              outcome: LevitTaskOutcome.dropped,
              runsInIsolate: config.runsInIsolate,
            ),
          );
          return LevitTaskExecution<T>._(
            taskId: taskId,
            executionId: executionId,
            disposition: LevitTaskSubmissionDisposition.dropped,
            result: Future<T>.error(LevitTaskDroppedException(taskId)),
            cancel: () {},
          );
        case LevitTaskConflictPolicy.restart:
          final freed = group!.outstanding
              .where((item) => item.state == _TaskExecutionState.queued)
              .length;
          if (maxPending != null && pendingCount - freed >= maxPending!) {
            throw LevitTaskQueueFullException(maxPending!);
          }
          _supersedeGroup(group);
          group = null;
        case LevitTaskConflictPolicy.enqueue:
          break;
        case LevitTaskConflictPolicy.coalesceLatest:
          final tail = group!.coalescedTail;
          if (tail != null && tail.state == _TaskExecutionState.queued) {
            _moveQueuedExecution(tail, config.priority);
            final deadline = _earliestDeadline(
              tail.config.deadline,
              config.deadline,
            );
            tail.config = config..deadline = deadline;
            _armDeadline(tail);
            captureExecution?.call(tail);
            _emitTaskEvent(
              _eventFor(
                tail,
                type: LevitTaskEventType.coalesced,
                phase: LevitTaskPhase.queued,
              ),
            );
            return _handleFor<T>(
              tail,
              LevitTaskSubmissionDisposition.coalesced,
            );
          }
      }
    }

    if (maxPending != null && pendingCount >= maxPending!) {
      throw LevitTaskQueueFullException(maxPending!);
    }
    final execution = _TaskExecution(
      taskId: taskId,
      schedulingKey: schedulingKey,
      executionId: _generateExecutionId(),
      ownerPath: ownerPath,
      queuedAt: DateTime.now(),
      config: config,
    );
    captureExecution?.call(execution);
    config.group._admitTask(execution);
    group ??= _groups.putIfAbsent(
      schedulingKey,
      () => _TaskGroup(schedulingKey),
    );
    group.outstanding.add(execution);
    _executions[execution.executionId] = execution;
    _pendingCount++;
    if (existing != null &&
        conflictPolicy == LevitTaskConflictPolicy.coalesceLatest) {
      group.coalescedTail = execution;
    }
    if (pendingCount == 1) _priorityCursor = 0;
    _queueFor(execution.config.priority).add(execution);
    _emitTaskEvent(
      _eventFor(
        execution,
        type: LevitTaskEventType.queued,
        phase: LevitTaskPhase.queued,
      ),
    );
    _armDeadline(execution);
    _notifyTaskTree();
    _processQueue();

    final disposition =
        existing != null && conflictPolicy == LevitTaskConflictPolicy.restart
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
      result: execution.completer.future.then((value) => value as T),
      cancel: () => cancelExecution(execution.executionId),
      takeCleanupFailure: () {
        final failure = execution.cleanupFailure;
        execution.cleanupFailure = null;
        return failure;
      },
    );
  }

  Queue<_TaskExecution> _queueFor(LevitTaskPriority priority) {
    return _queueForPriority(
      priority: priority,
      highPriorityQueue: _highPriorityQueue,
      normalPriorityQueue: _normalPriorityQueue,
      lowPriorityQueue: _lowPriorityQueue,
    );
  }

  void _moveQueuedExecution(
    _TaskExecution execution,
    LevitTaskPriority nextPriority,
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
    for (var offset = 0; offset < _priorityCycle.length; offset++) {
      final queue = _queueFor(_priorityCycle[_priorityCursor]);
      _priorityCursor = (_priorityCursor + 1) % _priorityCycle.length;
      for (final execution in queue) {
        if (_isEligible(execution)) {
          queue.remove(execution);
          return execution;
        }
      }
    }
    return null;
  }

  void _armDeadline(_TaskExecution execution) {
    execution.deadlineTimer?.cancel();
    execution.deadlineTimer = null;
    if (execution.state == _TaskExecutionState.completed) return;
    final deadline = execution.config.deadline;
    if (deadline == null) return;
    execution.deadlineTimer = Timer(deadline.difference(DateTime.now()), () {
      _cancelExecution(
        execution,
        LevitTaskSkipReason.cancelledWhileQueued,
        reason: const LevitTaskCancellationReason(
          LevitTaskCancellationKind.deadlineExceeded,
        ),
      );
    });
  }

  bool _isEligible(_TaskExecution execution) {
    if (execution.state != _TaskExecutionState.queued) return false;
    final group = _groups[execution.schedulingKey];
    return group != null &&
        group.outstanding.isNotEmpty &&
        identical(group.outstanding.first, execution);
  }

  void _start(_TaskExecution execution) {
    _pendingCount--;
    execution.state = _TaskExecutionState.running;
    execution.startedAt = DateTime.now();
    final group = _groups[execution.schedulingKey];
    if (identical(group?.coalescedTail, execution)) {
      group!.coalescedTail = null;
    }
    _activeExecutions.add(execution);
    _notifyTaskTree();
    final runner = runZoned(
      () => _run(execution),
      zoneValues: {
        _taskZoneKey: (group: execution.config.group, execution: execution),
      },
    );
    // Track the actual runner, including its async continuations/finally work.
    // A second completion proxy adds no lifetime protection.
    _runners.add(runner);
    unawaited(
      runner.whenComplete(() {
        _runners.remove(runner);
      }),
    );
  }

  Future<void> _run(_TaskExecution execution) async {
    final config = execution.config;

    try {
      // Keep admission asynchronous even without caching, without constructing
      // an additional no-op cache future for every execution.
      final cachedResult = await (config.cachePolicy == null
          ? null
          : _readCachedTaskResult<dynamic>(
              cacheProvider: cacheProvider,
              taskId: execution.taskId,
              cachePolicy: config.cachePolicy,
            ));
      if (execution.config.deadline case final deadline?) {
        if (!DateTime.now().isBefore(deadline))
          execution.cancellation.cancel(
            const LevitTaskCancellationReason(
              LevitTaskCancellationKind.deadlineExceeded,
            ),
          );
      }
      if (execution.cancellation.isCancelled) {
        _completeCancelled(
          execution,
          _cancellationReason(
            execution,
            LevitTaskSkipReason.cancelledBeforeStart,
          ),
        );
        return;
      }
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
          skipReason: LevitTaskSkipReason.cacheHit,
        );
        return;
      }

      config.onStart?.call();
      if (execution.cancellation.isCancelled) {
        _completeCancelled(
          execution,
          _cancellationReason(
            execution,
            LevitTaskSkipReason.cancelledBeforeStart,
          ),
        );
        return;
      }

      while (true) {
        execution.attempt++;
        _emitTaskEvent(
          _eventFor(
            execution,
            type: LevitTaskEventType.started,
            phase: LevitTaskPhase.running,
          ),
        );
        final context = LevitTaskContext._(
          taskId: execution.taskId,
          executionId: execution.executionId,
          attempt: execution.attempt,
          cancellation: execution.cancellation,
          group: config.group,
          deadline: config.deadline,
          reportProgress: (value) => _reportProgress(execution, value),
        );

        try {
          context.throwIfCancelled();
          // _start already establishes the execution and group zone, including
          // the self-disposal guard, for the runner and its continuations.
          final result = await config.task(context);
          if (execution.cancellation.isCancelled) {
            _completeCancelled(
              execution,
              _cancellationReason(
                execution,
                LevitTaskSkipReason.cancelledAfterRun,
              ),
            );
            return;
          }

          if (config.cachePolicy != null) {
            await _writeCachedTaskResult<dynamic>(
              cacheProvider: cacheProvider,
              taskId: execution.taskId,
              cachePolicy: config.cachePolicy,
              result: result,
            );
          }
          if (execution.cancellation.isCancelled) {
            _completeCancelled(
              execution,
              _cancellationReason(
                execution,
                LevitTaskSkipReason.cancelledAfterRun,
              ),
            );
            return;
          }
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
            if (error is! LevitTaskCancelledException) {
              final failure = LevitDisposalFailure(
                resource: execution.executionId,
                error: error,
                stackTrace: stackTrace,
              );
              execution.cleanupFailure = failure;
              if (_cleanupFailures.length < 64) {
                _cleanupFailures.add(failure);
              }
            }
            _completeCancelled(
              execution,
              _cancellationReason(
                execution,
                LevitTaskSkipReason.cancelledAfterRun,
              ),
              error: error,
              stackTrace: stackTrace,
            );
            return;
          }

          final retry = config.retryPolicy;
          if (retry != null &&
              execution.attempt <= retry.maxRetries &&
              retry.shouldRetry(error, stackTrace)) {
            final retryIn = retry.delayFor(execution.attempt);
            _emitTaskEvent(
              _eventFor(
                execution,
                type: LevitTaskEventType.retryScheduled,
                phase: LevitTaskPhase.retryWaiting,
                attempt: execution.attempt + 1,
                retryIn: retryIn,
                error: error,
                stackTrace: stackTrace,
              ),
            );
            final delay = Completer<void>();
            final timer = Timer(retryIn, delay.complete);
            try {
              await Future.any<void>([
                delay.future,
                execution.cancellation.cancelled,
              ]);
            } finally {
              timer.cancel();
            }
            if (execution.cancellation.isCancelled) {
              _completeCancelled(
                execution,
                _cancellationReason(
                  execution,
                  LevitTaskSkipReason.cancelledAfterRun,
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
          _cancellationReason(execution, LevitTaskSkipReason.cancelledAfterRun),
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
    _emitTaskEvent(
      _eventFor(
        execution,
        type: LevitTaskEventType.progress,
        phase: LevitTaskPhase.running,
        progress: value,
      ),
    );
  }

  void _completeValue(
    _TaskExecution execution,
    dynamic value, {
    required LevitTaskEventType eventType,
    required LevitTaskOutcome outcome,
    LevitTaskSkipReason? skipReason,
  }) {
    _emitTaskEvent(
      _eventFor(
        execution,
        type: eventType,
        phase: LevitTaskPhase.completed,
        progress: outcome == LevitTaskOutcome.succeeded
            ? 1
            : execution.progress,
        outcome: outcome,
        skipReason: skipReason,
      ),
    );
    _finalize(execution);
    execution.config.group._taskFinished(execution);
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
    _emitTaskEvent(
      _eventFor(
        execution,
        type: LevitTaskEventType.failed,
        phase: LevitTaskPhase.completed,
        outcome: LevitTaskOutcome.failed,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    _finalize(execution);
    execution.config.group._taskFinished(
      execution,
      deliveredError,
      deliveredStack,
    );
    if (!execution.completer.isCompleted) {
      execution.completer.completeError(deliveredError, deliveredStack);
    }
  }

  void _completeCancelled(
    _TaskExecution execution,
    LevitTaskSkipReason reason, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (execution.state == _TaskExecutionState.completed) return;
    final onCancel = execution.config.onCancel;
    final onEvent = execution.config.onEvent;
    final outcome = reason == LevitTaskSkipReason.superseded
        ? LevitTaskOutcome.superseded
        : LevitTaskOutcome.cancelled;
    final event = _eventFor(
      execution,
      type: LevitTaskEventType.skipped,
      phase: LevitTaskPhase.completed,
      outcome: outcome,
      skipReason: reason,
      error: error,
      stackTrace: stackTrace,
    );
    _finalize(execution);
    try {
      onCancel?.call();
    } catch (_) {
      // Cancellation observers do not change cancellation semantics.
    }
    _emitTaskEvent(event, onEvent: onEvent);
    execution.config.group._taskFinished(execution);
    if (!execution.completer.isCompleted)
      execution.completer.completeError(
        reason == LevitTaskSkipReason.superseded
            ? LevitTaskSupersededException(
                execution.taskId,
                execution.executionId,
              )
            : LevitTaskCancelledException(
                execution.taskId,
                execution.executionId,
                reason:
                    execution.cancellation.reason ??
                    const LevitTaskCancellationReason(
                      LevitTaskCancellationKind.requested,
                    ),
              ),
        stackTrace ?? StackTrace.current,
      );
  }

  LevitTaskSkipReason _cancellationReason(
    _TaskExecution execution,
    LevitTaskSkipReason fallback,
  ) {
    return execution.cancellationReason == LevitTaskSkipReason.superseded
        ? LevitTaskSkipReason.superseded
        : fallback;
  }

  void _finalize(_TaskExecution execution) {
    if (execution.state == _TaskExecutionState.completed) return;
    if (execution.state == _TaskExecutionState.queued) _pendingCount--;
    execution.state = _TaskExecutionState.completed;
    execution.deadlineTimer?.cancel();
    execution.deadlineTimer = null;
    _activeExecutions.remove(execution);
    _executions.remove(execution.executionId);
    final group = _groups[execution.schedulingKey];
    group?.outstanding.remove(execution);
    if (identical(group?.coalescedTail, execution)) {
      group!.coalescedTail = null;
    }
    if (group != null && group.outstanding.isEmpty) {
      _groups.remove(execution.schedulingKey);
    }
    _notifyTaskTree();
    _schedulePump();
  }

  LevitTaskEvent? _eventFor(
    _TaskExecution execution, {
    required LevitTaskEventType type,
    required LevitTaskPhase phase,
    int? attempt,
    Duration? retryIn,
    double? progress,
    LevitTaskSkipReason? skipReason,
    LevitTaskOutcome? outcome,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (execution.config.onEvent == null &&
        onTaskEvent == null &&
        LevitTaskMiddleware._middlewares.isEmpty)
      return null;
    final startedAt = execution.startedAt;
    final end = phase == LevitTaskPhase.completed ? DateTime.now() : null;
    return LevitTaskEvent(
      type: type,
      taskId: execution.taskId,
      executionId: execution.executionId,
      ownerPath: execution.ownerPath,
      phase: phase,
      metadata: execution.config.metadata,
      groupId: execution.config.group.id,
      parentGroupId: execution.config.group.parent?.id,
      deadline: execution.config.deadline,
      cancellationReason: execution.cancellation.reason,
      priority: execution.config.priority,
      attempt: attempt ?? execution.attempt,
      maxRetries: execution.config.retryPolicy?.maxRetries ?? 0,
      queuedAt: execution.queuedAt,
      startedAt: startedAt,
      finishedAt: end,
      queueDuration: startedAt == null
          ? null
          : startedAt.difference(execution.queuedAt),
      runDuration: end == null || startedAt == null
          ? null
          : end.difference(startedAt),
      retryIn: retryIn,
      progress: progress,
      skipReason: skipReason,
      outcome: outcome,
      error: error,
      stackTrace: stackTrace,
      runsInIsolate: execution.config.runsInIsolate,
    );
  }

  /// Reports [progress] (`0.0` to `1.0`) for the latest running execution of
  /// logical [id].
  ///
  /// Throws a [RangeError] if [progress] is non-finite or outside `[0.0, 1.0]`.
  /// Does nothing if no execution for [id] is currently running.
  void updateProgress(String id, double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw RangeError.range(progress, 0, 1, 'progress');
    }
    final candidates = _activeExecutions.where((item) => item.taskId == id);
    if (candidates.isEmpty) return;
    _reportProgress(candidates.last, progress);
  }

  /// Dynamically updates engine configuration.
  ///
  /// Non-null values update [maxConcurrent], [cacheProvider], and [ownerPath]
  /// (`null` leaves them unchanged). For [onTaskError] and [onTaskEvent],
  /// omitting the argument leaves the current callback unchanged, while
  /// explicitly passing `null` clears the callback.
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
      _cancelExecution(execution, LevitTaskSkipReason.cancelledWhileQueued);
    }
  }

  /// Cooperatively cancels one admitted execution by [executionId].
  ///
  /// Returns `true` if a matching execution was found (even if already
  /// completed), or `false` if [executionId] is unknown.
  bool cancelExecution(String executionId) {
    final execution = _executions[executionId];
    if (execution == null) return false;
    _cancelExecution(execution, LevitTaskSkipReason.cancelledWhileQueued);
    return true;
  }

  void _cancelExecution(
    _TaskExecution execution,
    LevitTaskSkipReason queuedReason, {
    LevitTaskCancellationReason reason = const LevitTaskCancellationReason(
      LevitTaskCancellationKind.requested,
    ),
  }) {
    if (execution.state == _TaskExecutionState.completed) return;
    execution.cancellationReason = queuedReason;
    execution.cancellation.cancel(
      queuedReason == LevitTaskSkipReason.superseded
          ? const LevitTaskCancellationReason(
              LevitTaskCancellationKind.superseded,
            )
          : reason,
    );
    _notifyTaskTree();
    if (execution.state == _TaskExecutionState.queued) {
      _queueFor(execution.config.priority).remove(execution);
      _completeCancelled(execution, queuedReason);
    }
  }

  void _supersedeGroup(_TaskGroup group) {
    final previous = List<_TaskExecution>.of(group.outstanding);
    group.outstanding.clear();
    group.coalescedTail = null;
    _groups.remove(group.key);
    for (final execution in previous) {
      execution.detachedByRestart = true;
      _cancelExecution(execution, LevitTaskSkipReason.superseded);
    }
  }

  /// Cooperatively cancels every outstanding execution.
  void cancelAll() {
    for (final group in rootGroup._children.toList()) {
      group.cancel();
    }
    for (final execution in List<_TaskExecution>.of(
      _executions.values,
      growable: false,
    )) {
      _cancelExecution(execution, LevitTaskSkipReason.cancelledWhileQueued);
    }
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('LevitTaskEngine is disposed.');
  }

  /// Throws a [StateError] if called synchronously from inside a task or group
  /// body running on this engine.
  ///
  /// Tracked work cannot await disposal of its own engine or controller.
  @override
  void assertCanDispose() {
    if (identical(_currentTaskZone?.execution?.config.group.engine, this) ||
        (identical(LevitTaskGroup.current?.engine, this) &&
            (LevitTaskGroup.current?._bodyRunning ?? false))) {
      throw StateError(
        'Tracked work cannot await disposal of its own engine or owner.',
      );
    }
  }

  /// Stops new task admissions and cooperatively cancels all active and queued
  /// work in [rootGroup].
  @override
  void requestCancel() {
    if (_disposed) return;
    _disposed = true;
    rootGroup.cancel(
      const LevitTaskCancellationReason(LevitTaskCancellationKind.ownerClosed),
    );
  }

  /// Cancels admitted work and waits until all active runners and cleanup
  /// handlers finish.
  ///
  /// Throws a [StateError] if called from inside tracked work on this engine,
  /// and throws a [LevitDisposalException] if cleanup handlers fail.
  @override
  Future<void> drain() async {
    assertCanDispose();
    requestCancel();
    final admitted = _runners.toList();
    await rootGroup.done;
    // Include runners present at admission and any started by group bodies
    // before the root sealed. A completed root cannot admit more runners.
    await Future.wait({...admitted, ..._runners});
    if (_cleanupFailures.isNotEmpty)
      throw LevitDisposalException.aggregate(_cleanupFailures);
  }

  /// Stops admissions, cancels work, and waits for execution cleanup.
  ///
  /// Cancellation is cooperative: an uncooperative task delays completion.
  /// A task must not await disposal of its own engine or controller.
  /// Safe to call multiple times; subsequent calls return the same [Future].
  @override
  Future<void> dispose() {
    assertCanDispose();
    requestCancel();
    return _disposeFuture ??= () async {
      try {
        await drain();
      } finally {
        await _taskTree?.close();
      }
    }();
  }
}

Future<T> _runInTaskIsolate<I, T>({
  required LevitIsolateTask<I, T> task,
  required I input,
  required LevitTaskContext context,
  required _LevitTaskCancellation cancellation,
}) async {
  final events = createIsolateReceivePort();
  final exited = Completer<void>();
  final result = Completer<T>();
  LevitIsolateSendPort? cancellationPort;

  void sendCancellation() => cancellationPort?.send(cancellation.reason);
  if (cancellation.isCancelled) sendCancellation();
  unawaited(cancellation.cancelled.then((_) => sendCancellation()));

  late final StreamSubscription<dynamic> eventSubscription;

  void completeError(Object error, StackTrace stackTrace) {
    if (!result.isCompleted) result.completeError(error, stackTrace);
  }

  eventSubscription = events.listen((dynamic raw) {
    if (raw == null) {
      if (!exited.isCompleted) exited.complete();
      if (!result.isCompleted) {
        completeError(
          StateError('Task isolate exited without a result.'),
          StackTrace.current,
        );
      }
      return;
    }
    if (raw is List<dynamic>) {
      final errText = raw.isNotEmpty ? raw[0].toString() : 'Isolate error';
      final stackText = raw.length > 1 && raw[1] != null
          ? raw[1].toString()
          : '';
      completeError(
        createIsolateRemoteError(errText, stackText),
        StackTrace.fromString(stackText),
      );
      return;
    }
    final message = raw as (Object, Object?);
    switch (message.$1) {
      case _IsolateTaskMessage.cancellationPort:
        cancellationPort = message.$2! as LevitIsolateSendPort;
        if (cancellation.isCancelled) sendCancellation();
      case _IsolateTaskMessage.progress:
        if (!cancellation.isCancelled) {
          context.reportProgress(message.$2! as double);
        }
      case _IsolateTaskMessage.success:
        if (!result.isCompleted) result.complete(message.$2 as T);
      case _IsolateTaskMessage.cancelled:
        completeError(
          LevitTaskCancelledException(
            context.taskId,
            context.executionId,
            reason:
                cancellation.reason ??
                const LevitTaskCancellationReason(
                  LevitTaskCancellationKind.requested,
                ),
          ),
          StackTrace.current,
        );
      case _IsolateTaskMessage.error:
        final errorParts = message.$2! as (String, String);
        completeError(
          createIsolateRemoteError(errorParts.$1, errorParts.$2),
          StackTrace.fromString(errorParts.$2),
        );
    }
  });
  try {
    await spawnDartIsolate<List<Object?>>(
      _levitTaskIsolateEntry,
      <Object?>[
        task,
        input,
        events.sendPort,
        context.taskId,
        context.executionId,
        context.attempt,
      ],
      onError: events.sendPort,
      onExit: events.sendPort,
      errorsAreFatal: true,
      debugName: context.executionId,
    );
    try {
      return await result.future;
    } finally {
      await exited.future;
    }
  } finally {
    await eventSubscription.cancel();
    events.close();
  }
}

void _levitTaskIsolateEntry(List<Object?> message) async {
  final task = message[0] as Function;
  final input = message[1];
  final eventPort = message[2]! as LevitIsolateSendPort;
  final taskId = message[3]! as String;
  final executionId = message[4]! as String;
  final attempt = message[5]! as int;
  final cancellationPort = createIsolateReceivePort();
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
    eventPort.send(
      error is LevitTaskCancelledException
          ? (_IsolateTaskMessage.cancelled, null)
          : (
              _IsolateTaskMessage.error,
              (error.toString(), stackTrace.toString()),
            ),
    );
  } finally {
    context._close();
  }
}
