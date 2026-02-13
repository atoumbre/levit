part of '../../levit_dart.dart';

final _taskEngines = Expando<LevitTaskEngine>();

/// A mixin for [LevitController] that adds advanced task management capabilities.
///
/// Features include:
/// *   Concurrency limits (queuing).
/// *   Task priority ([TaskPriority]).
/// *   Automatic retries with exponential backoff.
///
/// This mixin is focused on task execution and does not expose reactive state for UI consumption.
/// See [LevitReactiveTasksMixin] if you need UI-specific reactive state for tasks.
mixin LevitTasksMixin on LevitController {
  /// The task engine used by this mixin.
  LevitTaskEngine get tasksEngine => _taskEngines[this]!;

  /// Optional default error handler for all tasks run by this service.
  ///
  /// If provided, this function is called when a task fails after all retries.
  void Function(Object error, StackTrace? stackTrace)? get onTaskError => null;

  /// Optional lifecycle instrumentation callback for task engine events.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  /// The cache provider used by this mixin.
  ///
  /// Override this to provide a persistent storage implementation.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// The maximum number of concurrent tasks allowed.
  ///
  /// Defaults to a very large number (effectively infinite). Override this getter
  /// to enforce a limit (e.g., `3` for a connection pool).
  int get maxConcurrentTasks => 100000;

  @override
  void onInit() {
    super.onInit();
    var engine = _taskEngines[this];
    if (engine == null) {
      engine = LevitTaskEngine(
        maxConcurrent: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );
      _taskEngines[this] = engine;
    } else {
      engine.config(
        maxConcurrent: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );
    }
  }

  @override
  void onClose() {
    _taskEngines[this]?.cancelAll();
    super.onClose();
  }
}

/// A mixin for [LevitController] that combines task management with reactive state.
///
/// This mixin is ideal for controllers that drive UI needing to show loading states,
/// progress bars, or error messages for asynchronous operations.
///
/// It exposes:
/// *   [tasks]: A reactive map of task IDs to their current [TaskDetails].
/// *   [totalProgress]: A computed value (0.0 to 1.0) representing overall progress.
/// *   [isBusy]: A computed value indicating if any tasks are currently active.
mixin LevitReactiveTasksMixin on LevitController {
  /// The task engine used by this mixin.
  LevitTaskEngine get tasksEngine => _taskEngines[this]!;

  /// The maximum number of concurrent tasks allowed.
  int get maxConcurrentTasks => 100000;

  /// The maximum number of completed tasks to keep in history.
  ///
  /// Defaults to 50 to prevent unbounded memory growth.
  int get maxTaskHistory => 50;

  /// The cache provider used by this mixin.
  ///
  /// Override this to provide a persistent storage implementation.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// Optional delay before automatically removing a completed task.
  ///
  /// If null, tasks are kept until manually cleared or [maxTaskHistory] is reached.
  Duration? get autoCleanupDelay => null;

  void Function(Object error, StackTrace? stackTrace)? _onTaskError;

  /// Optional global error handler for tasks in this controller.
  void Function(Object error, StackTrace? stackTrace)? get onTaskError =>
      _onTaskError;

  /// Optional lifecycle instrumentation callback for task engine events.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  set onTaskError(void Function(Object error, StackTrace? stackTrace)? value) {
    _onTaskError = value;
    if (_taskEngines[this] != null) {
      if (value == null) {
        _taskEngines[this]!.config(onTaskError: null);
      } else {
        _taskEngines[this]!.config(
          onTaskError: (e, s) => value(e, s),
        );
      }
    }
  }

  /// A reactive map of task IDs to their details.
  final tasks = LxMap<String, TaskDetails>().named('tasks');

  /// A computed value representing the weighted average progress (0.0 to 1.0) of all active tasks.
  ///
  /// **Warning:** This computation iterates over all active tasks. If you have hundreds
  /// of concurrent tasks, accessing this frequently triggers an O(N) loop.
  late final LxComputed<double> totalProgress;

  /// A computed value indicating if any tasks are currently active.
  late final LxComputed<bool> isBusy;

  /// Timers for auto-cleanup.
  final _cleanupTimers = <String, Timer>{};

  void _updateTaskIfPresent(
    String taskId,
    TaskDetails Function(TaskDetails current) updater,
  ) {
    final current = tasks[taskId];
    if (current == null) return;
    tasks[taskId] = updater(current);
  }

  @override
  void onInit() {
    super.onInit();
    var engine = _taskEngines[this];
    if (engine == null) {
      engine = LevitTaskEngine(
        maxConcurrent: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );
      _taskEngines[this] = engine;
    } else {
      engine.config(
        maxConcurrent: maxConcurrentTasks,
        cacheProvider: taskCacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
      );
    }

    // Register reactive fields once so disposal remains controller-owned.
    autoDispose(tasks);

    totalProgress = (() {
      if (tasks.isEmpty) return 0.0;
      double sumProgress = 0;
      double sumWeight = 0;

      for (final id in tasks.keys) {
        final details = tasks[id]!;
        final status = details.status;
        final weight = details.weight;

        final p = switch (status) {
          LxSuccess() => 1.0,
          LxWaiting() => details.progress,
          _ => 0.0,
        };

        sumProgress += p * weight;
        sumWeight += weight;
      }

      return sumWeight == 0 ? 0.0 : sumProgress / sumWeight;
    }).lx.named('totalProgress');

    isBusy = (() => tasks.values.any((d) => d.status is LxWaiting))
        .lx
        .named('isBusy');

    autoDispose(isBusy);
    autoDispose(totalProgress);
  }

  /// Executes a [task] and automatically tracks its status in [tasks].
  ///
  /// *   [task]: The async function to execute.
  /// *   [id]: A unique ID for the task (optional, generated if null).
  /// *   [priority]: Task priority.
  /// *   [retries]: Number of retry attempts.
  /// *   [retryDelay]: Delay between retries.
  /// *   [useExponentialBackoff]: Exponential backoff strategy.
  /// *   [weight]: The weight of this task in [totalProgress] calculation (default 1.0).
  /// *   [onError]: Custom error handler.
  /// *   [cachePolicy]: If provided, the task result will be cached and reused until it expires.
  Future<T?> runTask<T>(
    FutureOr<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    bool runInIsolate = false,
    String? debugName,
  }) async {
    final taskId = id ?? LevitTaskEngine._generateTaskId();

    // Invariant: a task id maps to at most one active execution.
    if (tasks.containsKey(taskId) && tasks[taskId]?.status is LxWaiting) {
      throw StateError('Task with id "$taskId" is already running. '
          'Use a unique ID or cancel the existing task first.');
    }

    _cleanupTimers[taskId]?.cancel();
    _cleanupTimers.remove(taskId);

    // Keep bounded task history while preserving running entries.
    if (tasks.length >= maxTaskHistory && !tasks.containsKey(taskId)) {
      final keyToRemove = tasks.keys.firstWhere(
        (k) => tasks[k]?.status is! LxWaiting,
        orElse: () => '',
      );
      if (keyToRemove.isNotEmpty) {
        clearTask(keyToRemove);
      }
    }

    // Create waiting state immediately so queued tasks are visible to observers.
    tasks[taskId] = TaskDetails(
      status: LxWaiting<dynamic>(tasks[taskId]?.status.lastValue),
      weight: weight,
      progress: 0.0,
      started: false,
    );

    return tasksEngine.schedule<T>(
      task,
      id: taskId,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      cachePolicy: cachePolicy,
      runInIsolate: runInIsolate,
      debugName: debugName,
      onStart: () {
        _updateTaskIfPresent(
            taskId,
            (current) => current.copyWith(
                  started: true,
                  status: LxWaiting<dynamic>(tasks[taskId]?.status.lastValue),
                ));
      },
      onSuccess: (result) {
        _updateTaskIfPresent(
            taskId,
            (current) => current.copyWith(
                  status: LxSuccess<T>(result),
                  progress: 1.0,
                ));
        _scheduleCleanup(taskId);
      },
      onProgress: (p) {
        _updateTaskIfPresent(
            taskId, (current) => current.copyWith(progress: p));
      },
      onError: (e, s) {
        _updateTaskIfPresent(
            taskId,
            (current) => current.copyWith(
                  status:
                      LxError<Object>(e, s, tasks[taskId]?.status.lastValue),
                ));
        final handler = onError ?? onTaskError;
        handler?.call(e, s);
        _scheduleCleanup(taskId);
      },
      onCancel: () {
        _cleanupTimers[taskId]?.cancel();
        _cleanupTimers.remove(taskId);
        tasks.remove(taskId);
      },
    );
  }

  void _scheduleCleanup(String id) {
    if (autoCleanupDelay == null) return;
    _cleanupTimers[id]?.cancel();
    _cleanupTimers[id] = Timer(autoCleanupDelay!, () {
      _cleanupTimers.remove(id);
      if (tasks.containsKey(id) && tasks[id]?.status is! LxWaiting) {
        clearTask(id);
      }
    });
  }

  /// Manually update the progress of a specific task.
  ///
  /// *   [id]: The task ID.
  /// *   [value]: The progress value (0.0 to 1.0).
  void updateTaskProgress(String id, double value) {
    if (tasks.containsKey(id)) {
      final normalized =
          value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
      tasks[id] = tasks[id]!.copyWith(progress: normalized);
      tasksEngine.updateProgress(id, normalized);
    }
  }

  /// Clears a task from the state map and cancels it if running.
  void clearTask(String id) {
    tasks.remove(id);
    _cleanupTimers[id]?.cancel();
    _cleanupTimers.remove(id);
    cancelTask(id);
  }

  /// Clears all completed ([LxSuccess] or [LxIdle]) tasks from the state map.
  void clearCompleted() {
    final keys = tasks.keys
        .where((id) =>
            tasks[id]?.status is LxSuccess ||
            tasks[id]?.status is LxIdle ||
            tasks[id]?.status is LxError)
        .toList();
    for (final id in keys) {
      clearTask(id);
    }
  }

  /// Cancels a specific task.
  void cancelTask(String id) => tasksEngine.cancel(id);

  /// Cancels all tasks.
  void cancelAllTasks() => tasksEngine.cancelAll();

  @override
  void onClose() {
    _taskEngines[this]?.cancelAll();
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    super.onClose();
  }
}
