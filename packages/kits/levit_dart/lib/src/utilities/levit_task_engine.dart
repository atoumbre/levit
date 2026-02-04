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

  final Map<String, _ActiveTask> _activeTasks = {};
  final Queue<_QueuedTask> _queue = Queue<_QueuedTask>();

  /// Creates a task engine with [maxConcurrent] workers.
  LevitTaskEngine({
    required this.maxConcurrent,
    LevitTaskCacheProvider? cacheProvider,
    this.onTaskError,
  }) : cacheProvider = cacheProvider ?? InMemoryTaskCacheProvider();

  static int _nextTaskId = 0;

  static String _generateTaskId() =>
      'task_${DateTime.now().microsecondsSinceEpoch}_${_nextTaskId++}';

  // static final _defaultCacheProvider = InMemoryTaskCacheProvider();

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
            return result;
          } catch (e) {
            // If deserialization fails, treat as cache miss and delete
            await cacheProvider.delete(cacheKey);
          }
        } else {
          // Expired
          await cacheProvider.delete(cacheKey);
        }
      }
    }

    // If we can run now, run.
    if (_activeTasks.length < maxConcurrent) {
      return _execute<T>(
        id: taskId,
        task: task,
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
      // Enqueue
      final completer = Completer<T?>();
      _queue.add(_QueuedTask<T>(
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
      _sortQueue(); // Ensure highest priority is first
      return completer.future;
    }
  }

  void _sortQueue() {
    // Sort logic: High (0) < Normal (1) < Low (2). Min first.
    final list = _queue.toList(growable: false);
    list.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    _queue
      ..clear()
      ..addAll(list);
  }

  Future<T?> _execute<T>({
    required String id,
    required FutureOr<T> Function() task,
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
    // Track active task
    final activeTaskNode = _ActiveTask(id, onProgress: onProgress);
    _activeTasks[id] = activeTaskNode;

    onStart?.call();

    int attempts = 0;
    while (true) {
      if (activeTaskNode.isCancelled) {
        _finalize(id);
        onCancel?.call();
        return null;
      }

      try {
        final result = runInIsolate
            ? await Isolate.run(task, debugName: debugName)
            : await task();
        if (activeTaskNode.isCancelled) {
          _finalize(id);
          onCancel?.call();
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
        return result;
      } catch (e, s) {
        if (attempts < retries && !activeTaskNode.isCancelled) {
          attempts++;
          final baseDelay = retryDelay ?? const Duration(milliseconds: 500);
          final delay = useExponentialBackoff
              ? baseDelay * math.pow(2, attempts - 1)
              : baseDelay;

          await Future.delayed(delay);
          continue; // Retry loop
        }

        // Final failure
        _finalize(id);
        if (activeTaskNode.isCancelled) {
          onCancel?.call();
        } else {
          final handler = onError ?? onTaskError;
          handler?.call(e, s);
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
    // Start as many queued tasks as possible up to maxConcurrent limit
    while (_queue.isNotEmpty && _activeTasks.length < maxConcurrent) {
      final next = _queue.removeFirst(); // Takes highest priority
      _runQueued(next);
    }
  }

  Future<void> _runQueued(_QueuedTask item) async {
    try {
      final result = await _execute(
        id: item.id,
        task: item.task,
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
      item.completer.complete(result);
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
    void Function(Object error, StackTrace stackTrace)? onTaskError,
  }) {
    if (maxConcurrent != null) {
      this.maxConcurrent = maxConcurrent;
      _processQueue();
    }
    if (cacheProvider != null) this.cacheProvider = cacheProvider;
    if (onTaskError != null) this.onTaskError = onTaskError;
  }

  /// Cancels a running or queued task by [id].
  void cancel(String id) {
    if (_activeTasks.containsKey(id)) {
      _activeTasks[id]!.isCancelled = true;
    }
    _queue.removeWhere((item) => item.id == id);
  }

  /// Cancels all running and queued tasks.
  void cancelAll() {
    for (var t in _activeTasks.values) {
      t.isCancelled = true;
    }
    _queue.clear();
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
