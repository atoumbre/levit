part of '../../levit_dart.dart';

final _taskEngines = Expando<LevitTaskEngine>();

LevitTaskEngine _resolveTasksEngine(
  LevitController controller, {
  required int maxConcurrentTasks,
  LevitTaskCacheProvider? cacheProvider,
  void Function(Object error, StackTrace stackTrace)? onTaskError,
  void Function(LevitTaskEvent event)? onTaskEvent,
  bool reconfigure = false,
}) {
  var engine = _taskEngines[controller];
  if (engine == null) {
    final created = controller.own(LevitTaskEngine(
      maxConcurrent: maxConcurrentTasks,
      cacheProvider: cacheProvider,
      onTaskError: onTaskError,
      onTaskEvent: onTaskEvent,
      ownerPath: controller.ownerPath,
    ));
    _taskEngines[controller] = created;
    return created;
  }

  if (reconfigure) {
    engine.config(
      maxConcurrent: maxConcurrentTasks,
      cacheProvider: cacheProvider,
      onTaskError: onTaskError,
      onTaskEvent: onTaskEvent,
      ownerPath: controller.ownerPath,
    );
  }

  return engine;
}

LevitTaskEngine _tasksEngineFor(
  LevitController controller, {
  required int maxConcurrentTasks,
  LevitTaskCacheProvider? cacheProvider,
  void Function(Object error, StackTrace stackTrace)? onTaskError,
  void Function(LevitTaskEvent event)? onTaskEvent,
}) {
  if (controller.isClosed) {
    throw StateError('tasksEngine accessed after the controller was closed.');
  }

  return _resolveTasksEngine(
    controller,
    maxConcurrentTasks: maxConcurrentTasks,
    cacheProvider: cacheProvider,
    onTaskError: onTaskError,
    onTaskEvent: onTaskEvent,
  );
}

/// Adds named task execution, conflict policies, retries, and cancellation.
mixin LevitTasksMixin on LevitController {
  /// The controller-owned task engine.
  LevitTaskEngine get tasksEngine => _tasksEngineFor(
        this,
        maxConcurrentTasks: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );

  /// Optional default error handler for terminal failures.
  void Function(Object error, StackTrace stackTrace)? get onTaskError => null;

  /// Optional controller-local task event observer.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  /// Optional persistent cache provider.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// Maximum number of concurrent task executions.
  int get maxConcurrentTasks => 100000;

  /// Runs a task using this controller's owned engine.
  Future<T?> runTask<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return tasksEngine.schedule<T>(
      task,
      id: id,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
      metadata: metadata,
      debugName: debugName,
    );
  }

  /// Runs a top-level/static task in a new isolate.
  Future<T?> runIsolateTask<I, T>(
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
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return tasksEngine.scheduleIsolate<I, T>(
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
      metadata: metadata,
      debugName: debugName,
    );
  }

  @override
  void onInit() {
    super.onInit();
    _resolveTasksEngine(
      this,
      maxConcurrentTasks: maxConcurrentTasks,
      cacheProvider: taskCacheProvider,
      onTaskError: onTaskError,
      onTaskEvent: onTaskEvent,
      reconfigure: true,
    );
  }

  @override
  FutureOr<void> onClose() {
    _taskEngines[this]?.cancelAll();
    return super.onClose();
  }
}

/// Adds reactive task state and selectors to [LevitController].
mixin LevitReactiveTasksMixin on LevitController {
  /// The controller-owned task engine.
  LevitTaskEngine get tasksEngine => _tasksEngineFor(
        this,
        maxConcurrentTasks: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );

  /// Maximum number of concurrent task executions.
  int get maxConcurrentTasks => 100000;

  /// Maximum number of terminal logical task entries retained.
  int get maxTaskHistory => 50;

  /// Optional persistent cache provider.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// Optional delay before terminal entries are removed.
  Duration? get autoCleanupDelay => null;

  void Function(Object error, StackTrace stackTrace)? _onTaskError;

  /// Optional global error handler for tasks in this controller.
  void Function(Object error, StackTrace stackTrace)? get onTaskError =>
      _onTaskError;

  /// Optional controller-local task event observer.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  set onTaskError(void Function(Object, StackTrace)? value) {
    _onTaskError = value;
    _taskEngines[this]?.config(onTaskError: value);
  }

  /// Latest execution details keyed by logical task ID.
  final tasks = LxMap<String, TaskDetails>().named('tasks');

  LxComputed<double>? _totalProgress;
  LxComputed<bool>? _isBusy;
  LxComputed<bool>? _hasBlockingTasks;
  bool _reactiveTaskStateInitialized = false;

  /// Weighted progress across all retained tasks.
  LxComputed<double> get totalProgress {
    _ensureReactiveTaskState();
    return _totalProgress!;
  }

  /// Whether any latest logical execution is queued or running.
  LxComputed<bool> get isBusy {
    _ensureReactiveTaskState();
    return _isBusy!;
  }

  /// Whether any active task is marked as blocking.
  LxComputed<bool> get hasBlockingTasks {
    _ensureReactiveTaskState();
    return _hasBlockingTasks!;
  }

  final _cleanupTimers = <String, Timer>{};

  void _ensureReactiveTaskState() {
    if (isClosed) {
      throw StateError(
        'Reactive task state accessed after the controller was closed.',
      );
    }
    if (_reactiveTaskStateInitialized) return;

    _reactiveTaskStateInitialized = true;
    own(tasks);
    _totalProgress = (() => progressWhere()).lx.named('totalProgress');
    _isBusy = (() => isBusyWhere()).lx.named('isBusy');
    _hasBlockingTasks = (() {
      return isBusyWhere(blocksUserInteraction: true);
    }).lx.named('hasBlockingTasks');
    own(_isBusy!);
    own(_totalProgress!);
    own(_hasBlockingTasks!);
  }

  /// Returns the latest details for logical [id].
  TaskDetails? taskDetails(String id) => tasks[id];

  /// Returns the latest status for [id], or an idle status when absent.
  LxStatus<T> taskStatus<T>(String id) {
    final status = tasks[id]?.status;
    if (status == null) return LxIdle<T>();
    final lastValue = status.lastValue as T?;
    return switch (status) {
      LxIdle() => LxIdle<T>(lastValue),
      LxWaiting() => LxWaiting<T>(lastValue),
      LxSuccess(:final value) => LxSuccess<T>(value as T),
      LxError(:final error, :final stackTrace) =>
        LxError<T>(error, stackTrace, lastValue),
    };
  }

  /// Whether logical [id] is queued or running.
  bool isTaskRunning(String id) {
    final phase = tasks[id]?.phase;
    return phase == LevitTaskPhase.queued ||
        phase == LevitTaskPhase.running ||
        phase == LevitTaskPhase.retryWaiting;
  }

  /// Latest progress for logical [id].
  double taskProgress(String id) => tasks[id]?.progress ?? 0;

  /// Whether matching tasks contain any queued or running work.
  bool isBusyWhere({
    String? category,
    bool? blocksUserInteraction,
  }) {
    return tasks.values.any((details) {
      if (!_matchesTaskFilter(
        details,
        category: category,
        blocksUserInteraction: blocksUserInteraction,
      )) {
        return false;
      }
      return details.phase != LevitTaskPhase.completed;
    });
  }

  /// Weighted progress across tasks matching category/blocking filters.
  double progressWhere({
    String? category,
    bool? blocksUserInteraction,
  }) {
    var progress = 0.0;
    var weight = 0.0;
    for (final details in tasks.values) {
      if (!_matchesTaskFilter(
        details,
        category: category,
        blocksUserInteraction: blocksUserInteraction,
      )) {
        continue;
      }
      final value = switch (details.status) {
        LxSuccess() => 1.0,
        LxWaiting() => details.progress,
        _ => 0.0,
      };
      progress += value * details.weight;
      weight += details.weight;
    }
    return weight == 0 ? 0 : progress / weight;
  }

  bool _matchesTaskFilter(
    TaskDetails details, {
    String? category,
    bool? blocksUserInteraction,
  }) {
    if (category != null && details.metadata.category != category) return false;
    if (blocksUserInteraction != null &&
        details.metadata.blocksUserInteraction != blocksUserInteraction) {
      return false;
    }
    return true;
  }

  void _updateExecution(
    String taskId,
    String executionId,
    TaskDetails Function(TaskDetails current) update,
  ) {
    final current = tasks[taskId];
    if (current == null || current.executionId != executionId) return;
    tasks[taskId] = update(current);
  }

  void _applyTaskEvent(LevitTaskEvent event) {
    _updateExecution(event.taskId, event.executionId, (current) {
      return current.copyWith(
        ownerPath: event.ownerPath,
        phase: event.phase,
        metadata: event.metadata,
        priority: event.priority,
        attempt: event.attempt,
        outcome: event.outcome,
        progress: event.progress,
        started: event.startedAt != null,
        queuedAt: event.queuedAt,
        startedAt: event.startedAt,
        finishedAt: event.finishedAt,
        queueDuration: event.queueDuration,
        runDuration: event.runDuration,
      );
    });
    if (event.phase == LevitTaskPhase.completed) {
      _scheduleCleanup(event.taskId);
    }
  }

  @override
  void onInit() {
    super.onInit();
    _resolveTasksEngine(
      this,
      maxConcurrentTasks: maxConcurrentTasks,
      cacheProvider: taskCacheProvider,
      onTaskError: onTaskError,
      onTaskEvent: onTaskEvent,
      reconfigure: true,
    );
    _ensureReactiveTaskState();
  }

  /// Executes [task] and tracks the latest execution for its logical ID.
  Future<T?> runTask<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureReactiveTaskState();
    if (!weight.isFinite || weight < 0) {
      throw RangeError.value(weight, 'weight');
    }

    final taskId = id ?? LevitTaskEngine._generateTaskId();
    final taskMetadata = metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    LevitTaskEvent? queuedEvent;
    late final LevitTaskExecution<T> execution;

    execution = tasksEngine.submit<T>(
      task,
      id: taskId,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      cachePolicy: cachePolicy,
      metadata: taskMetadata,
      onEvent: (event) {
        queuedEvent ??= event;
        _applyTaskEvent(event);
      },
      onSuccess: (result) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxSuccess<T>(result),
            progress: 1,
          );
        });
      },
      onProgress: (progress) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(progress: progress);
        });
      },
      onError: (error, stackTrace) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxError<Object>(
              error,
              stackTrace,
              current.status.lastValue,
            ),
          );
        });
        (onError ?? this.onTaskError)?.call(error, stackTrace);
      },
      onCancel: () {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxIdle<dynamic>(current.status.lastValue),
          );
        });
      },
    );

    if (execution.disposition == LevitTaskSubmissionDisposition.joined ||
        execution.disposition == LevitTaskSubmissionDisposition.dropped) {
      return execution.result;
    }

    _cleanupTimers.remove(taskId)?.cancel();
    _pruneTaskHistoryFor(taskId);
    final initialEvent = queuedEvent;
    tasks[taskId] = TaskDetails(
      status: LxWaiting<dynamic>(tasks[taskId]?.status.lastValue),
      executionId: execution.executionId,
      ownerPath: initialEvent?.ownerPath ?? ownerPath,
      phase: initialEvent?.phase ?? LevitTaskPhase.queued,
      metadata: taskMetadata,
      priority: priority,
      attempt: initialEvent?.attempt ?? 0,
      weight: weight,
      progress: 0,
      started: false,
      queuedAt: initialEvent?.queuedAt ?? DateTime.now(),
    );
    return execution.result;
  }

  /// Executes a top-level/static isolate task and tracks its state.
  Future<T?> runIsolateTask<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return _runTrackedIsolateTask<I, T>(
      task,
      input,
      id: id,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      weight: weight,
      onError: onError,
      cachePolicy: cachePolicy,
      metadata: metadata,
      debugName: debugName,
    );
  }

  Future<T?> _runTrackedIsolateTask<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    required TaskPriority priority,
    required TaskConflictPolicy conflictPolicy,
    required int retries,
    required Duration? retryDelay,
    required bool useExponentialBackoff,
    required double weight,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    _ensureReactiveTaskState();
    if (!weight.isFinite || weight < 0) {
      throw RangeError.value(weight, 'weight');
    }

    final taskId = id ?? LevitTaskEngine._generateTaskId();
    final taskMetadata = metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    LevitTaskEvent? queuedEvent;
    late final LevitTaskExecution<T> execution;
    execution = tasksEngine.submitIsolate<I, T>(
      task,
      input,
      id: taskId,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      cachePolicy: cachePolicy,
      metadata: taskMetadata,
      onEvent: (event) {
        queuedEvent ??= event;
        _applyTaskEvent(event);
      },
      onSuccess: (result) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxSuccess<T>(result),
            progress: 1,
          );
        });
      },
      onProgress: (progress) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(progress: progress);
        });
      },
      onError: (error, stackTrace) {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxError<Object>(
              error,
              stackTrace,
              current.status.lastValue,
            ),
          );
        });
        (onError ?? this.onTaskError)?.call(error, stackTrace);
      },
      onCancel: () {
        _updateExecution(taskId, execution.executionId, (current) {
          return current.copyWith(
            status: LxIdle<dynamic>(current.status.lastValue),
          );
        });
      },
    );

    if (execution.disposition == LevitTaskSubmissionDisposition.joined ||
        execution.disposition == LevitTaskSubmissionDisposition.dropped) {
      return execution.result;
    }

    _cleanupTimers.remove(taskId)?.cancel();
    _pruneTaskHistoryFor(taskId);
    final initialEvent = queuedEvent;
    tasks[taskId] = TaskDetails(
      status: LxWaiting<dynamic>(tasks[taskId]?.status.lastValue),
      executionId: execution.executionId,
      ownerPath: initialEvent?.ownerPath ?? ownerPath,
      phase: initialEvent?.phase ?? LevitTaskPhase.queued,
      metadata: taskMetadata,
      priority: priority,
      weight: weight,
      queuedAt: initialEvent?.queuedAt ?? DateTime.now(),
    );
    return execution.result;
  }

  void _pruneTaskHistoryFor(String taskId) {
    if (tasks.length < maxTaskHistory || tasks.containsKey(taskId)) return;
    final removable = tasks.keys.cast<String?>().firstWhere(
          (key) => key != null && tasks[key]?.phase == LevitTaskPhase.completed,
          orElse: () => null,
        );
    if (removable != null) clearTask(removable);
  }

  void _scheduleCleanup(String id) {
    final delay = autoCleanupDelay;
    if (delay == null) return;
    _cleanupTimers.remove(id)?.cancel();
    _cleanupTimers[id] = Timer(delay, () {
      _cleanupTimers.remove(id);
      if (tasks[id]?.phase == LevitTaskPhase.completed) clearTask(id);
    });
  }

  /// Validates and reports progress for the latest running execution of [id].
  void updateTaskProgress(String id, double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
    final current = tasks[id];
    if (current == null) return;
    tasks[id] = current.copyWith(progress: value);
    tasksEngine.updateProgress(id, value);
  }

  /// Clears tracked state and cancels outstanding executions for [id].
  void clearTask(String id) {
    tasks.remove(id);
    _cleanupTimers.remove(id)?.cancel();
    cancelTask(id);
  }

  /// Clears all terminal tracked entries.
  void clearCompleted() {
    final keys = tasks.keys.where((id) {
      final details = tasks[id];
      return details != null &&
          details.phase == LevitTaskPhase.completed &&
          details.status is! LxWaiting;
    }).toList(growable: false);
    for (final id in keys) {
      clearTask(id);
    }
  }

  /// Cancels all outstanding executions for logical [id].
  void cancelTask(String id) => tasksEngine.cancel(id);

  /// Cancels all outstanding controller tasks.
  void cancelAllTasks() => tasksEngine.cancelAll();

  @override
  FutureOr<void> onClose() {
    _taskEngines[this]?.cancelAll();
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    return super.onClose();
  }
}
