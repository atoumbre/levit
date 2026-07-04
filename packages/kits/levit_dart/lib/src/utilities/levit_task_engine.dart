part of '../../levit_dart.dart';

/// A standalone engine for managing asynchronous tasks with concurrency limits,
/// priority queues, and automatic retries.
///
/// Implement [LevitDisposable] to allow for easy cleanup when used within
/// [LevitStore] or [LevitController].
class LevitTaskEngine implements LevitDisposable {
  /// The maximum number of concurrent tasks allowed.
  int maxConcurrent;

  /// The cache provider used by this engine.
  LevitTaskCacheProvider cacheProvider;

  /// Optional global error handler for all tasks run by this engine.
  void Function(Object error, StackTrace stackTrace)? onTaskError;

  /// Optional lifecycle instrumentation stream for task/queue transitions.
  void Function(LevitTaskEvent event)? onTaskEvent;

  final Map<String, _ActiveTask> _activeTasks = {};
  final Queue<_QueuedTask> _highPriorityQueue = Queue<_QueuedTask>();
  final Queue<_QueuedTask> _normalPriorityQueue = Queue<_QueuedTask>();
  final Queue<_QueuedTask> _lowPriorityQueue = Queue<_QueuedTask>();

  /// Creates a task engine with [maxConcurrent] workers.
  LevitTaskEngine({
    required this.maxConcurrent,
    LevitTaskCacheProvider? cacheProvider,
    this.onTaskError,
    this.onTaskEvent,
  }) : cacheProvider = cacheProvider ?? InMemoryTaskCacheProvider();

  static int _nextTaskId = 0;

  static String _generateTaskId() =>
      'task_${DateTime.now().microsecondsSinceEpoch}_${_nextTaskId++}';

  static void _onTaskErrorUnset(Object error, StackTrace stackTrace) {}
  static void _onTaskEventUnset(LevitTaskEvent event) {}

  void _emitTaskEvent(LevitTaskEvent event) {
    onTaskEvent?.call(event);
  }

  /// Schedules a [task] for execution.
  ///
  /// *   If active tasks < [maxConcurrent], executes immediately.
  /// *   Otherwise, enqueues the task based on [priority].
  Future<T?> schedule<T>(
    FutureOr<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    Function(Object, StackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(dynamic result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    bool runInIsolate = false,
    String? debugName,
  }) async {
    final taskId = id ?? _generateTaskId();

    if (cachePolicy != null) {
      final cachedResult = await _readCachedTaskResult<T>(
        cacheProvider: cacheProvider,
        taskId: taskId,
        cachePolicy: cachePolicy,
      );
      if (cachedResult != null) {
        final result = cachedResult.result;
        onSuccess?.call(result);
        _emitTaskEvent(LevitTaskEvent(
          type: LevitTaskEventType.skipped,
          taskId: taskId,
          priority: priority,
          maxRetries: retries,
          skipReason: TaskSkipReason.cacheHit,
          runInIsolate: runInIsolate,
          debugName: debugName,
        ));
        return result;
      }
    }

    // Run immediately when capacity exists; otherwise enqueue by priority.
    if (_activeTasks.length < maxConcurrent) {
      return _execute<T>(
        id: taskId,
        task: task,
        priority: priority,
        retries: retries,
        retryDelay: retryDelay,
        useExponentialBackoff: useExponentialBackoff,
        onError: onError,
        cachePolicy: cachePolicy,
        onStart: onStart,
        onSuccess: onSuccess,
        onProgress: onProgress,
        onCancel: onCancel,
        runInIsolate: runInIsolate,
        debugName: debugName,
      );
    } else {
      final completer = Completer<T?>();
      _enqueue(_QueuedTask<T>(
        id: taskId,
        task: task,
        priority: priority,
        retries: retries,
        retryDelay: retryDelay,
        useExponentialBackoff: useExponentialBackoff,
        onError: onError,
        completer: completer,
        cachePolicy: cachePolicy,
        onStart: onStart,
        onSuccess: onSuccess,
        onProgress: onProgress,
        onCancel: onCancel,
        runInIsolate: runInIsolate,
        debugName: debugName,
      ));
      return completer.future;
    }
  }

  void _enqueue(_QueuedTask item) {
    _queueForPriority(
      priority: item.priority,
      highPriorityQueue: _highPriorityQueue,
      normalPriorityQueue: _normalPriorityQueue,
      lowPriorityQueue: _lowPriorityQueue,
    ).add(item);
    _emitTaskEvent(LevitTaskEvent(
      type: LevitTaskEventType.queued,
      taskId: item.id,
      priority: item.priority,
      maxRetries: item.retries,
      runInIsolate: item.runInIsolate,
      debugName: item.debugName,
    ));
  }

  bool get _hasQueuedTasks => _hasQueuedTasksInQueues(
        highPriorityQueue: _highPriorityQueue,
        normalPriorityQueue: _normalPriorityQueue,
        lowPriorityQueue: _lowPriorityQueue,
      );

  _QueuedTask? _takeNextQueuedTask() => _takeNextQueuedTaskFromQueues(
        highPriorityQueue: _highPriorityQueue,
        normalPriorityQueue: _normalPriorityQueue,
        lowPriorityQueue: _lowPriorityQueue,
      );

  Future<T?> _execute<T>({
    required String id,
    required FutureOr<T> Function() task,
    required TaskPriority priority,
    required int retries,
    required Duration? retryDelay,
    required bool useExponentialBackoff,
    required Function(Object, StackTrace)? onError,
    required TaskCachePolicy<T>? cachePolicy,
    void Function()? onStart,
    void Function(dynamic result)? onSuccess,
    void Function(double progress)? onProgress,
    void Function()? onCancel,
    bool runInIsolate = false,
    String? debugName,
  }) async {
    // Active task map is the source of truth for cancellation/progress.
    final activeTaskNode = _ActiveTask(id, onProgress: onProgress);
    _activeTasks[id] = activeTaskNode;

    onStart?.call();
    _emitTaskEvent(LevitTaskEvent(
      type: LevitTaskEventType.started,
      taskId: id,
      priority: priority,
      attempt: 1,
      maxRetries: retries,
      runInIsolate: runInIsolate,
      debugName: debugName,
    ));

    int attempts = 0;
    while (true) {
      if (activeTaskNode.isCancelled) {
        _finalize(id);
        onCancel?.call();
        _emitTaskEvent(LevitTaskEvent(
          type: LevitTaskEventType.skipped,
          taskId: id,
          priority: priority,
          attempt: attempts,
          maxRetries: retries,
          skipReason: TaskSkipReason.cancelledBeforeStart,
          runInIsolate: runInIsolate,
          debugName: debugName,
        ));
        return null;
      }

      try {
        final result = runInIsolate
            ? await Isolate.run(task, debugName: debugName)
            : await task();
        if (activeTaskNode.isCancelled) {
          _finalize(id);
          onCancel?.call();
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.skipped,
            taskId: id,
            priority: priority,
            attempt: attempts + 1,
            maxRetries: retries,
            skipReason: TaskSkipReason.cancelledAfterRun,
            runInIsolate: runInIsolate,
            debugName: debugName,
          ));
          return null;
        }

        await _writeCachedTaskResult<T>(
          cacheProvider: cacheProvider,
          taskId: id,
          cachePolicy: cachePolicy,
          result: result,
        );

        _finalize(id);
        onSuccess?.call(result);
        _emitTaskEvent(LevitTaskEvent(
          type: LevitTaskEventType.finished,
          taskId: id,
          priority: priority,
          attempt: attempts + 1,
          maxRetries: retries,
          runInIsolate: runInIsolate,
          debugName: debugName,
        ));
        return result;
      } catch (e, s) {
        if (attempts < retries && !activeTaskNode.isCancelled) {
          attempts++;
          final baseDelay = retryDelay ?? const Duration(milliseconds: 500);
          final delay = useExponentialBackoff
              ? baseDelay * math.pow(2, attempts - 1)
              : baseDelay;
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.retryScheduled,
            taskId: id,
            priority: priority,
            attempt: attempts + 1,
            maxRetries: retries,
            retryIn: delay,
            error: e,
            stackTrace: s,
            runInIsolate: runInIsolate,
            debugName: debugName,
          ));

          await Future.delayed(delay);
          continue; // Retry loop
        }

        // Retries exhausted: propagate terminal failure or cancellation.
        _finalize(id);
        if (activeTaskNode.isCancelled) {
          onCancel?.call();
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.skipped,
            taskId: id,
            priority: priority,
            attempt: attempts + 1,
            maxRetries: retries,
            skipReason: TaskSkipReason.cancelledAfterRun,
            error: e,
            stackTrace: s,
            runInIsolate: runInIsolate,
            debugName: debugName,
          ));
        } else {
          final handler = onError ?? onTaskError;
          handler?.call(e, s);
          _emitTaskEvent(LevitTaskEvent(
            type: LevitTaskEventType.failed,
            taskId: id,
            priority: priority,
            attempt: attempts + 1,
            maxRetries: retries,
            error: e,
            stackTrace: s,
            runInIsolate: runInIsolate,
            debugName: debugName,
          ));
          rethrow;
        }
      }
    }
  }

  void _finalize(String id) {
    _activeTasks.remove(id);
    _processQueue();
  }

  void _processQueue() {
    // Drain queues until concurrency limit is reached.
    while (_hasQueuedTasks && _activeTasks.length < maxConcurrent) {
      final next = _takeNextQueuedTask();
      if (next == null) return;
      _runQueued(next);
    }
  }

  Future<void> _runQueued(_QueuedTask item) async {
    try {
      final result = await _execute(
        id: item.id,
        task: item.task,
        priority: item.priority,
        retries: item.retries,
        retryDelay: item.retryDelay,
        useExponentialBackoff: item.useExponentialBackoff,
        onError: item.onError,
        cachePolicy: item.cachePolicy,
        onStart: item.onStart,
        onSuccess: item.onSuccess,
        onProgress: item.onProgress,
        onCancel: item.onCancel,
        runInIsolate: item.runInIsolate,
        debugName: item.debugName,
      );
      if (!item.completer.isCompleted) {
        item.completer.complete(result);
      }
    } catch (e, s) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(e, s);
      }
    }
  }

  /// Updates the progress of a specific running task.
  void updateProgress(String id, double progress) {
    _activeTasks[id]?.onProgress?.call(progress);
  }

  /// Dynamically updates the engine configuration.
  void config({
    int? maxConcurrent,
    LevitTaskCacheProvider? cacheProvider,
    void Function(Object error, StackTrace stackTrace)? onTaskError =
        _onTaskErrorUnset,
    void Function(LevitTaskEvent event)? onTaskEvent = _onTaskEventUnset,
  }) {
    if (maxConcurrent != null) {
      this.maxConcurrent = maxConcurrent;
      _processQueue();
    }
    if (cacheProvider != null) this.cacheProvider = cacheProvider;
    if (!identical(onTaskError, _onTaskErrorUnset)) {
      this.onTaskError = onTaskError;
    }
    if (!identical(onTaskEvent, _onTaskEventUnset)) {
      this.onTaskEvent = onTaskEvent;
    }
  }

  /// Cancels a running or queued task by [id].
  void cancel(String id) {
    if (_activeTasks.containsKey(id)) {
      _activeTasks[id]!.isCancelled = true;
    }
    _cancelQueuedByIdInQueue(
      _highPriorityQueue,
      id,
      emitTaskEvent: _emitTaskEvent,
    );
    _cancelQueuedByIdInQueue(
      _normalPriorityQueue,
      id,
      emitTaskEvent: _emitTaskEvent,
    );
    _cancelQueuedByIdInQueue(
      _lowPriorityQueue,
      id,
      emitTaskEvent: _emitTaskEvent,
    );
  }

  /// Cancels all running and queued tasks.
  void cancelAll() {
    for (var t in _activeTasks.values) {
      t.isCancelled = true;
    }
    _cancelAllQueuedInQueue(_highPriorityQueue, emitTaskEvent: _emitTaskEvent);
    _cancelAllQueuedInQueue(_normalPriorityQueue,
        emitTaskEvent: _emitTaskEvent);
    _cancelAllQueuedInQueue(_lowPriorityQueue, emitTaskEvent: _emitTaskEvent);
  }

  @override
  void dispose() {
    cancelAll();
  }
}
