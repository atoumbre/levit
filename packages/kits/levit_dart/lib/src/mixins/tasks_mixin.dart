part of '../kit_library.dart';

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
    final created = controller.own(
      LevitTaskEngine(
        maxConcurrent: maxConcurrentTasks,
        cacheProvider: cacheProvider,
        onTaskError: onTaskError,
        onTaskEvent: onTaskEvent,
        ownerPath: controller.ownerPath,
      ),
    );
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
    throw StateError('taskEngine accessed after the controller was closed.');
  }

  return _resolveTasksEngine(
    controller,
    maxConcurrentTasks: maxConcurrentTasks,
    cacheProvider: cacheProvider,
    onTaskError: onTaskError,
    onTaskEvent: onTaskEvent,
  );
}

Future<void> _drainTaskEngineBeforeClose(
  LevitController controller,
  FutureOr<void> Function() superOnBeforeClose,
) async {
  final failures = <LevitDisposalFailure>[];
  Future<void> runStep(Object resource, FutureOr<void> Function() step) async {
    try {
      await step();
    } on LevitDisposalException catch (error) {
      failures.addAll(error.failures);
    } catch (error, stackTrace) {
      failures.add(
        LevitDisposalFailure(
          resource: resource,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  final engine = _taskEngines[controller];
  if (engine != null) await runStep(engine, engine.dispose);
  await runStep(controller, superOnBeforeClose);
  if (failures.isNotEmpty) throw LevitDisposalException.aggregate(failures);
}

/// Adds named task execution, conflict policies, retries, and cancellation to a
/// [LevitController] without UI-facing reactive task state.
///
/// The owned [taskEngine] drains and disposes in [onBeforeClose] before other
/// owned resources close. Subclasses overriding [onInit] or [onBeforeClose]
/// must delegate to `super` (`super.onInit()` and `await super.onBeforeClose()`).
///
/// For reactive busy state, progress selectors, and per-task [LxStatus], use
/// [LevitReactiveTasksMixin]. To reference advanced task types such as
/// `LevitTaskEngine`, `LevitTaskGroup`, or `LevitTaskCachePolicy` directly,
/// import `package:levit_dart/tasks.dart` (or `package:levit/tasks.dart` /
/// `package:levit_flutter/tasks.dart`).
///
/// ```dart
/// class SyncController extends LevitController with LevitTasksMixin {
///   Future<void> syncNow() => runTask(
///     (ctx) async {
///       ctx.throwIfCancelled();
///       await api.sync();
///     },
///     id: 'sync',
///     conflictPolicy: LevitTaskConflictPolicy.join,
///   );
/// }
/// ```
///
/// {@category Tasks & Concurrency}
mixin LevitTasksMixin on LevitController {
  /// The controller-owned task engine.
  ///
  /// Throws a [StateError] if accessed after this controller is closed.
  LevitTaskEngine get taskEngine => _tasksEngineFor(
    this,
    maxConcurrentTasks: maxConcurrentTasks,
    cacheProvider: taskCacheProvider,
    onTaskError: onTaskError,
    onTaskEvent: onTaskEvent,
  );

  /// Supervisor boundary for independent workflows owned by this controller.
  LevitTaskGroup get taskGroup => taskEngine.rootGroup;

  /// Optional default error handler for terminal failures.
  void Function(Object error, StackTrace stackTrace)? get onTaskError => null;

  /// Optional controller-local task event observer.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  /// Optional custom task cache provider. Defaults to an in-memory cache.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// Maximum number of concurrent task executions.
  int get maxConcurrentTasks => 8;

  /// Runs a task using this controller's owned engine.
  Future<T> runTask<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    void Function(Object, StackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return taskEngine.schedule<T>(
      task,
      id: id,
      priority: priority,
      conflictPolicy: conflictPolicy,
      retryPolicy: retryPolicy,
      group: group,
      deadline: deadline,
      onError: onError,
      cachePolicy: cachePolicy,
      metadata: metadata,
      debugName: debugName,
    );
  }

  /// Runs a top-level/static task in a new isolate.
  Future<T> runIsolateTask<I, T>(
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
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return taskEngine.scheduleIsolate<I, T>(
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
  FutureOr<void> onBeforeClose() =>
      _drainTaskEngineBeforeClose(this, () => super.onBeforeClose());
}

/// Adds reactive task state, progress aggregation, and selectors to a
/// [LevitController].
///
/// Exposes [tasks], [isBusy], [hasBlockingTasks], [totalProgress], and filtered
/// selectors ([taskStatus], [isTaskRunning], [isBusyWhere], [progressWhere]).
/// The owned [taskEngine] drains and disposes in [onBeforeClose] before other
/// owned resources close. Subclasses overriding [onInit] or [onBeforeClose]
/// must delegate to `super` (`super.onInit()` and `await super.onBeforeClose()`).
///
/// To reference advanced task types such as `LevitTaskEngine`,
/// `LevitTaskGroup`, or `LevitTaskCachePolicy` directly, import
/// `package:levit_dart/tasks.dart` (or `package:levit/tasks.dart` /
/// `package:levit_flutter/tasks.dart`).
///
/// ```dart
/// class ReportsController extends LevitController with LevitReactiveTasksMixin {
///   Future<String> generateReport() => runTask<String>(
///     (ctx) async {
///       ctx.reportProgress(0.5);
///       ctx.throwIfCancelled();
///       return await api.buildReport();
///     },
///     id: 'report',
///     conflictPolicy: LevitTaskConflictPolicy.restart,
///     retryPolicy: const LevitRetryPolicy(maxRetries: 2),
///   );
/// }
/// ```
///
/// {@category Tasks & Concurrency}
mixin LevitReactiveTasksMixin on LevitController {
  /// The controller-owned task engine.
  ///
  /// Throws a [StateError] if accessed after this controller is closed.
  LevitTaskEngine get taskEngine => _tasksEngineFor(
    this,
    maxConcurrentTasks: maxConcurrentTasks,
    cacheProvider: taskCacheProvider,
    onTaskError: onTaskError,
    onTaskEvent: onTaskEvent,
  );

  /// Supervisor boundary (`taskEngine.rootGroup`) for independent workflows
  /// owned by this controller.
  LevitTaskGroup get taskGroup => taskEngine.rootGroup;

  /// Maximum number of concurrent task executions.
  int get maxConcurrentTasks => 8;

  /// Target cap on the total number of entries retained in [tasks].
  ///
  /// When adding a new logical task ID at or above this limit, at most one
  /// oldest completed entry is evicted.
  int get maxTaskHistory => 50;

  /// Optional custom task cache provider. Defaults to an in-memory cache.
  LevitTaskCacheProvider? get taskCacheProvider => null;

  /// Optional delay before terminal entries are removed.
  Duration? get autoCleanupDelay => null;

  void Function(Object error, StackTrace stackTrace)? _onTaskError;

  /// Optional default error handler for terminal task failures in this controller.
  void Function(Object error, StackTrace stackTrace)? get onTaskError =>
      _onTaskError;

  /// Optional controller-local task event observer.
  void Function(LevitTaskEvent event)? get onTaskEvent => null;

  /// Updates the default error handler and reconfigures the active [taskEngine]
  /// if already initialized.
  set onTaskError(void Function(Object, StackTrace)? value) {
    _onTaskError = value;
    _taskEngines[this]?.config(onTaskError: value);
  }

  /// Latest execution details keyed by logical task ID.
  final tasks = LxMap<String, LevitTaskDetails>().named('tasks');

  LxComputed<double>? _totalProgress;
  LxComputed<bool>? _isBusy;
  LxComputed<bool>? _hasBlockingTasks;
  bool _reactiveTaskStateInitialized = false;

  /// Weighted progress (`0.0` to `1.0`) across all retained tasks.
  ///
  /// Computes the weighted average where [LxSuccess] contributes `1.0`,
  /// [LxWaiting] contributes its `progress`, and other statuses contribute
  /// `0.0` (returns `0.0` when total weight is `0`). Throws a [StateError] if
  /// accessed after this controller is closed.
  LxComputed<double> get totalProgress {
    _ensureReactiveTaskState();
    return _totalProgress!;
  }

  /// Whether any latest logical execution is queued, running, or waiting to retry.
  ///
  /// Throws a [StateError] if accessed after this controller is closed.
  LxComputed<bool> get isBusy {
    _ensureReactiveTaskState();
    return _isBusy!;
  }

  /// Whether any active task is marked as blocking user interaction.
  ///
  /// Throws a [StateError] if accessed after this controller is closed.
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
  LevitTaskDetails? taskDetails(String id) => tasks[id];

  /// Returns the latest status for [id], or an idle status when absent.
  LxStatus<T> taskStatus<T>(String id) {
    final status = tasks[id]?.status;
    if (status == null) return LxIdle<T>();
    final lastValue = status.lastValue as T?;
    return switch (status) {
      LxIdle() =>
        status.hasLastValue ? LxIdle<T>.retained(lastValue as T) : LxIdle<T>(),
      LxWaiting() =>
        status.hasLastValue
            ? LxWaiting<T>.retained(lastValue as T)
            : LxWaiting<T>(),
      LxSuccess(:final value) => LxSuccess<T>(value as T),
      LxError(:final error, :final stackTrace) =>
        status.hasLastValue
            ? LxError<T>.retained(error, lastValue as T, stackTrace)
            : LxError<T>(error, stackTrace),
    };
  }

  /// Whether logical [id] is queued, running, or waiting to retry.
  bool isTaskRunning(String id) {
    final phase = tasks[id]?.phase;
    return phase == LevitTaskPhase.queued ||
        phase == LevitTaskPhase.running ||
        phase == LevitTaskPhase.retryWaiting;
  }

  /// Latest progress for logical [id].
  double taskProgress(String id) => tasks[id]?.progress ?? 0;

  /// Whether matching tasks contain any queued, running, or retry-waiting work.
  bool isBusyWhere({String? category, bool? blocksUserInteraction}) {
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
  double progressWhere({String? category, bool? blocksUserInteraction}) {
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
    LevitTaskDetails details, {
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
    LevitTaskDetails Function(LevitTaskDetails current) update,
  ) {
    final current = tasks[taskId];
    if (current == null || current.executionId != executionId) return;
    tasks[taskId] = update(current);
  }

  void _applyTaskEvent(
    LevitTaskEvent event, {
    LxStatus<dynamic> Function(LxStatus<dynamic> previous)? statusOverride,
    double? progressOverride,
  }) {
    _updateExecution(event.taskId, event.executionId, (current) {
      return current.copyWith(
        status: statusOverride?.call(current.status),
        ownerPath: event.ownerPath,
        groupId: event.groupId,
        parentGroupId: event.parentGroupId,
        deadline: event.deadline,
        cancellationReason: event.cancellationReason,
        phase: event.phase,
        metadata: event.metadata,
        priority: event.priority,
        attempt: event.attempt,
        outcome: event.outcome,
        progress: progressOverride ?? event.progress,
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

  /// Executes [task] and tracks the latest execution for its logical [id] in
  /// [tasks].
  ///
  /// [weight] must be finite and non-negative (defaults to `1.0`); throws a
  /// [RangeError] otherwise. Joined and dropped submissions preserve the
  /// existing [tasks] entry without overwriting it. Cancellation reverts the
  /// status to [LxIdle] while retaining the last successful value.
  Future<T> runTask<T>(
    FutureOr<T> Function(LevitTaskContext context) task, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return _runTrackedTask<T>(
      id: id,
      priority: priority,
      weight: weight,
      onError: onError,
      metadata: metadata,
      debugName: debugName,
      submit:
          ({
            required taskId,
            required taskMetadata,
            required onEvent,
            required onSuccess,
            required onFailure,
            required onCancel,
          }) => taskEngine.submit<T>(
            task,
            id: taskId,
            priority: priority,
            conflictPolicy: conflictPolicy,
            retryPolicy: retryPolicy,
            group: group,
            deadline: deadline,
            cachePolicy: cachePolicy,
            metadata: taskMetadata,
            onEvent: onEvent,
            onSuccess: onSuccess,
            onError: onFailure,
            onCancel: onCancel,
          ),
    );
  }

  /// Executes a top-level or static isolate [task] with [input] and tracks its
  /// reactive state in [tasks].
  ///
  /// Both [input] and the return value [T] must be sendable across isolate
  /// boundaries. See [runTask] for parameter and state-tracking semantics.
  Future<T> runIsolateTask<I, T>(
    LevitIsolateTask<I, T> task,
    I input, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    LevitTaskGroup? group,
    DateTime? deadline,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    LevitTaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
    String? debugName,
  }) {
    return _runTrackedTask<T>(
      id: id,
      priority: priority,
      weight: weight,
      onError: onError,
      metadata: metadata,
      debugName: debugName,
      submit:
          ({
            required taskId,
            required taskMetadata,
            required onEvent,
            required onSuccess,
            required onFailure,
            required onCancel,
          }) => taskEngine.submitIsolate<I, T>(
            task,
            input,
            id: taskId,
            priority: priority,
            conflictPolicy: conflictPolicy,
            retryPolicy: retryPolicy,
            group: group,
            deadline: deadline,
            cachePolicy: cachePolicy,
            metadata: taskMetadata,
            onEvent: onEvent,
            onSuccess: onSuccess,
            onError: onFailure,
            onCancel: onCancel,
          ),
    );
  }

  Future<T> _runTrackedTask<T>({
    required String? id,
    required LevitTaskPriority priority,
    required double weight,
    required void Function(Object error, StackTrace stackTrace)? onError,
    required LevitTaskMetadata? metadata,
    required String? debugName,
    required LevitTaskExecution<T> Function({
      required String taskId,
      required LevitTaskMetadata taskMetadata,
      required void Function(LevitTaskEvent event) onEvent,
      required void Function(T result) onSuccess,
      required void Function(Object error, StackTrace stackTrace) onFailure,
      required void Function() onCancel,
    })
    submit,
  }) {
    _ensureReactiveTaskState();
    if (!weight.isFinite || weight < 0) {
      throw RangeError.value(weight, 'weight');
    }

    final taskId = id ?? LevitTaskEngine._generateTaskId();
    final taskMetadata =
        metadata ??
        (debugName == null
            ? LevitTaskMetadata.none
            : LevitTaskMetadata(debugName: debugName));
    LevitTaskEvent? latestEvent;
    String? executionId;
    LxStatus<dynamic> Function(LxStatus<dynamic> previous)? pendingStatus;
    double? pendingProgress;
    final execution = submit(
      taskId: taskId,
      taskMetadata: taskMetadata,
      onEvent: (event) {
        executionId ??= event.executionId;
        latestEvent = event;
        final statusUpdate = pendingStatus;
        final progressUpdate = pendingProgress;
        pendingStatus = null;
        pendingProgress = null;
        _applyTaskEvent(
          event,
          statusOverride: statusUpdate,
          progressOverride: progressUpdate,
        );
      },
      onSuccess: (result) {
        pendingStatus = (_) => LxSuccess<T>(result);
        pendingProgress = 1;
      },
      onFailure: (error, stackTrace) {
        final handler = onError ?? this.onTaskError;
        if (handler != null) {
          final idForUpdate = executionId;
          if (idForUpdate != null) {
            _updateExecution(taskId, idForUpdate, (current) {
              return current.copyWith(
                status: LxError<dynamic>.fromPrevious(
                  error,
                  stackTrace,
                  current.status,
                ),
              );
            });
          }
          handler(error, stackTrace);
        } else {
          pendingStatus = (prev) =>
              LxError<dynamic>.fromPrevious(error, stackTrace, prev);
        }
      },
      onCancel: () {
        pendingStatus = LxIdle<dynamic>.fromPrevious;
      },
    );
    executionId ??= execution.executionId;

    if (execution.disposition == LevitTaskSubmissionDisposition.joined ||
        execution.disposition == LevitTaskSubmissionDisposition.dropped) {
      return execution.result;
    }

    _cleanupTimers.remove(taskId)?.cancel();
    _pruneTaskHistoryFor(taskId);
    final initialEvent = latestEvent;
    final previousStatus = tasks[taskId]?.status ?? LxIdle<dynamic>();
    final initialPhase = initialEvent?.phase ?? LevitTaskPhase.queued;
    final initialStatus = initialPhase == LevitTaskPhase.completed
        ? LxIdle<dynamic>.fromPrevious(previousStatus)
        : LxWaiting<dynamic>.fromPrevious(previousStatus);
    tasks[taskId] = LevitTaskDetails(
      status: initialStatus,
      executionId: execution.executionId,
      ownerPath: initialEvent?.ownerPath ?? ownerPath,
      groupId: initialEvent?.groupId,
      parentGroupId: initialEvent?.parentGroupId,
      deadline: initialEvent?.deadline,
      cancellationReason: initialEvent?.cancellationReason,
      phase: initialPhase,
      metadata: taskMetadata,
      priority: priority,
      attempt: initialEvent?.attempt ?? 0,
      weight: weight,
      progress: 0,
      started: initialPhase == LevitTaskPhase.running,
      queuedAt: initialEvent?.queuedAt ?? DateTime.now(),
      finishedAt: initialEvent?.finishedAt,
      outcome: initialEvent?.outcome,
    );
    if (initialPhase == LevitTaskPhase.completed) {
      _scheduleCleanup(taskId);
    }
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
    if (isClosed) return;
    final delay = autoCleanupDelay;
    if (delay == null) return;
    _cleanupTimers.remove(id)?.cancel();
    _cleanupTimers[id] = Timer(delay, () {
      _cleanupTimers.remove(id);
      if (isClosed) return;
      if (tasks[id]?.phase == LevitTaskPhase.completed) clearTask(id);
    });
  }

  /// Validates and reports progress (`0.0` to `1.0`) for the latest running
  /// execution of [id].
  ///
  /// Throws a [RangeError] if [value] is non-finite or outside `[0.0, 1.0]`.
  /// Does nothing if [id] is not tracked in [tasks].
  void updateTaskProgress(String id, double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
    final current = tasks[id];
    if (current == null) return;
    taskEngine.updateProgress(id, value);
    final updated = tasks[id];
    if (updated != null && updated.progress != value) {
      tasks[id] = updated.copyWith(progress: value);
    }
  }

  /// Clears tracked state and cancels outstanding executions for [id].
  void clearTask(String id) {
    tasks.remove(id);
    _cleanupTimers.remove(id)?.cancel();
    if (!isClosed) {
      cancelTask(id);
    } else {
      _taskEngines[this]?.cancel(id);
    }
  }

  /// Clears all terminal tracked entries.
  void clearCompleted() {
    final keys = tasks.keys
        .where((id) {
          final details = tasks[id];
          return details != null &&
              details.phase == LevitTaskPhase.completed &&
              details.status is! LxWaiting;
        })
        .toList(growable: false);
    for (final id in keys) {
      clearTask(id);
    }
  }

  /// Cancels all outstanding executions for logical [id].
  void cancelTask(String id) => taskEngine.cancel(id);

  /// Cancels all outstanding controller tasks.
  void cancelAllTasks() => taskEngine.cancelAll();

  @override
  FutureOr<void> onBeforeClose() {
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    return _drainTaskEngineBeforeClose(this, () => super.onBeforeClose());
  }
}
