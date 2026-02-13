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

/// Lifecycle event types emitted by [LevitTaskEngine].
enum LevitTaskEventType {
  queued,
  started,
  retryScheduled,
  finished,
  failed,
  skipped,
}

/// Reasons why a task execution was skipped.
enum TaskSkipReason {
  cacheHit,
  cancelledWhileQueued,
  cancelledBeforeStart,
  cancelledAfterRun,
}

/// Structured lifecycle event emitted by [LevitTaskEngine].
class LevitTaskEvent {
  final LevitTaskEventType type;
  final String taskId;
  final TaskPriority priority;
  final int attempt;
  final int maxRetries;
  final DateTime timestamp;
  final Duration? retryIn;
  final TaskSkipReason? skipReason;
  final Object? error;
  final StackTrace? stackTrace;
  final bool runInIsolate;
  final String? debugName;

  LevitTaskEvent({
    required this.type,
    required this.taskId,
    required this.priority,
    this.attempt = 0,
    this.maxRetries = 0,
    this.retryIn,
    this.skipReason,
    this.error,
    this.stackTrace,
    this.runInIsolate = false,
    this.debugName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
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
      final cacheKey = cachePolicy.key ?? taskId;
      final cachedJson = await cacheProvider.read(cacheKey);

      if (cachedJson != null) {
        final expiresAt =
            DateTime.fromMillisecondsSinceEpoch(cachedJson['expiresAt'] as int);
        if (DateTime.now().isBefore(expiresAt)) {
          final data = cachedJson['data'] as Map<String, dynamic>;
          try {
            final result = cachePolicy.fromJson(data);
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
          } catch (e) {
            // Corrupt cache entries are purged and treated as cache misses.
            await cacheProvider.delete(cacheKey);
          }
        } else {
          // Expired entries are removed eagerly to keep cache reads deterministic.
          await cacheProvider.delete(cacheKey);
        }
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
    switch (item.priority) {
      case TaskPriority.high:
        _highPriorityQueue.add(item);
        break;
      case TaskPriority.normal:
        _normalPriorityQueue.add(item);
        break;
      case TaskPriority.low:
        _lowPriorityQueue.add(item);
        break;
    }
    _emitTaskEvent(LevitTaskEvent(
      type: LevitTaskEventType.queued,
      taskId: item.id,
      priority: item.priority,
      maxRetries: item.retries,
      runInIsolate: item.runInIsolate,
      debugName: item.debugName,
    ));
  }

  bool get _hasQueuedTasks =>
      _highPriorityQueue.isNotEmpty ||
      _normalPriorityQueue.isNotEmpty ||
      _lowPriorityQueue.isNotEmpty;

  _QueuedTask? _takeNextQueuedTask() {
    if (_highPriorityQueue.isNotEmpty) return _highPriorityQueue.removeFirst();
    if (_normalPriorityQueue.isNotEmpty) {
      return _normalPriorityQueue.removeFirst();
    }
    if (_lowPriorityQueue.isNotEmpty) return _lowPriorityQueue.removeFirst();
    return null;
  }

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

        if (cachePolicy != null) {
          final cacheKey = cachePolicy.key ?? id;
          await cacheProvider.write(cacheKey, {
            'expiresAt':
                DateTime.now().add(cachePolicy.ttl).millisecondsSinceEpoch,
            'data': cachePolicy.toJson(result),
          });
        }

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

  void _cancelQueuedTask(_QueuedTask item) {
    item.onCancel?.call();
    _emitTaskEvent(LevitTaskEvent(
      type: LevitTaskEventType.skipped,
      taskId: item.id,
      priority: item.priority,
      maxRetries: item.retries,
      skipReason: TaskSkipReason.cancelledWhileQueued,
      runInIsolate: item.runInIsolate,
      debugName: item.debugName,
    ));
    if (!item.completer.isCompleted) {
      item.completer.complete(null);
    }
  }

  void _cancelQueuedByIdInQueue(Queue<_QueuedTask> queue, String id) {
    if (queue.isEmpty) return;
    final retained = Queue<_QueuedTask>();
    for (final item in queue) {
      if (item.id == id) {
        _cancelQueuedTask(item);
      } else {
        retained.add(item);
      }
    }
    queue
      ..clear()
      ..addAll(retained);
  }

  void _cancelAllQueuedInQueue(Queue<_QueuedTask> queue) {
    for (final item in queue) {
      _cancelQueuedTask(item);
    }
    queue.clear();
  }

  /// Cancels a running or queued task by [id].
  void cancel(String id) {
    if (_activeTasks.containsKey(id)) {
      _activeTasks[id]!.isCancelled = true;
    }
    _cancelQueuedByIdInQueue(_highPriorityQueue, id);
    _cancelQueuedByIdInQueue(_normalPriorityQueue, id);
    _cancelQueuedByIdInQueue(_lowPriorityQueue, id);
  }

  /// Cancels all running and queued tasks.
  void cancelAll() {
    for (var t in _activeTasks.values) {
      t.isCancelled = true;
    }
    _cancelAllQueuedInQueue(_highPriorityQueue);
    _cancelAllQueuedInQueue(_normalPriorityQueue);
    _cancelAllQueuedInQueue(_lowPriorityQueue);
  }

  @override
  void dispose() {
    cancelAll();
  }
}

class _ActiveTask {
  final String id;
  bool isCancelled = false;
  final void Function(double progress)? onProgress;
  _ActiveTask(this.id, {this.onProgress});
}

class _QueuedTask<T> {
  final String id;
  final FutureOr<T> Function() task;
  final TaskPriority priority;
  final int retries;
  final Duration? retryDelay;
  final bool useExponentialBackoff;
  final Function(Object, StackTrace)? onError;
  final TaskCachePolicy<T>? cachePolicy;
  final void Function()? onStart;
  final void Function(dynamic result)? onSuccess;
  final void Function(double progress)? onProgress;
  final void Function()? onCancel;
  final bool runInIsolate;
  final String? debugName;
  final Completer<T?> completer;

  _QueuedTask({
    required this.id,
    required this.task,
    required this.priority,
    required this.retries,
    required this.retryDelay,
    required this.onError,
    required this.completer,
    this.useExponentialBackoff = true,
    this.cachePolicy,
    this.onStart,
    this.onSuccess,
    this.onProgress,
    this.onCancel,
    this.runInIsolate = false,
    this.debugName,
  });
}

/// Represents the details of a task, including its status, weight, and progress.
class TaskDetails {
  /// The current status of the task.
  final LxStatus<dynamic> status;

  /// The weight of the task, used for calculating total progress.
  final double weight;

  /// The progress of the task (0.0 to 1.0).
  final double progress;

  /// Whether the task has started executing.
  final bool started;

  /// Creates a new task details object.
  const TaskDetails({
    required this.status,
    this.weight = 1.0,
    this.progress = 0.0,
    this.started = false,
  });

  /// Creates a copy of this task details with the given fields replaced.
  TaskDetails copyWith({
    LxStatus<dynamic>? status,
    double? weight,
    double? progress,
    bool? started,
  }) {
    return TaskDetails(
      status: status ?? this.status,
      weight: weight ?? this.weight,
      progress: progress ?? this.progress,
      started: started ?? this.started,
    );
  }
}
