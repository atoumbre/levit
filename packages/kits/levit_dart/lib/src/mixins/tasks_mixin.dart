import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:levit_dart_core/levit_dart_core.dart';

int _nextTaskId = 0;
String _generateTaskId() =>
    'task_${DateTime.now().microsecondsSinceEpoch}_${_nextTaskId++}';

// ============================================================================
// Service and Controller Mixins
// ============================================================================

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
  late final _TaskEngine _tasksEngine;

  /// The maximum number of concurrent tasks allowed.
  ///
  /// Defaults to a very large number (effectively infinite). Override this getter
  /// to enforce a limit (e.g., `3` for a connection pool).
  int get maxConcurrentTasks => 100000;

  /// Optional default error handler for all tasks run by this service.
  ///
  /// If provided, this function is called when a task fails after all retries.
  void Function(Object error, StackTrace stackTrace)? onServiceError;

  /// The cache provider used by this mixin.
  ///
  /// Defaults to an [InMemoryTaskCacheProvider]. Override this to provide
  /// a persistent storage implementation.
  LevitTaskCacheProvider get taskCacheProvider => _defaultCacheProvider;
  static final _defaultCacheProvider = InMemoryTaskCacheProvider();

  @override
  void onInit() {
    super.onInit();
    _tasksEngine = _TaskEngine(maxConcurrent: maxConcurrentTasks);
  }

  /// Executes an asynchronous [task] with optional retry and priority logic.
  ///
  /// Returns the result of the task, or throws if it fails (unless handled internally).
  ///
  /// *   [task]: The async function to execute.
  /// *   [id]: An optional ID for the task (useful for cancellation).
  /// *   [priority]: The priority of the task relative to others in the queue.
  /// *   [retries]: The number of times to retry the task upon failure.
  /// *   [retryDelay]: The initial delay before the first retry.
  /// *   [useExponentialBackoff]: Whether to increase the delay exponentially for subsequent retries.
  /// *   [onError]: A custom error handler for this specific task. If not provided, [onServiceError] is used.
  /// *   [cachePolicy]: If provided, the task result will be cached and reused until it expires.
  Future<T?> runTask<T>(
    Future<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
  }) async {
    final taskId = id ?? _generateTaskId();

    if (cachePolicy != null) {
      final cacheKey = cachePolicy.key ?? taskId;
      final cachedJson = await taskCacheProvider.read(cacheKey);

      if (cachedJson != null) {
        final expiresAt =
            DateTime.fromMillisecondsSinceEpoch(cachedJson['expiresAt'] as int);
        if (DateTime.now().isBefore(expiresAt)) {
          final data = cachedJson['data'] as Map<String, dynamic>;
          try {
            return cachePolicy.fromJson(data);
          } catch (e) {
            // If deserialization fails, treat as cache miss and delete
            await taskCacheProvider.delete(cacheKey);
          }
        } else {
          // Expired
          await taskCacheProvider.delete(cacheKey);
        }
      }
    }

    final result = await _tasksEngine.schedule(
      task: task,
      id: taskId,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: (e, s) {
        final handler = onError ?? onServiceError;
        if (handler != null) {
          handler.call(e, s);
        } else {
          // If no handler, we allow the engine to complete the future with an error
          // to ensure propagation.
          throw e;
        }
      },
    );

    if (cachePolicy != null && result != null) {
      final cacheKey = cachePolicy.key ?? taskId;
      await taskCacheProvider.write(cacheKey, {
        'expiresAt': DateTime.now().add(cachePolicy.ttl).millisecondsSinceEpoch,
        'data': cachePolicy.toJson(result),
      });
    }

    return result;
  }

  /// Cancels a specific task by its ID.
  ///
  /// If the task is running, it will be marked for cancellation (though the Future cannot be interrupted).
  /// If it is queued, it will be removed from the queue.
  void cancelTask(String id) => _tasksEngine.cancel(id);

  /// Cancels all running and queued tasks.
  void cancelAllTasks() => _tasksEngine.cancelAll();

  @override
  void onClose() {
    _tasksEngine.cancelAll();
    super.onClose();
  }

  /// Executes a [task] in a separate [Isolate] using [Isolate.run].
  ///
  /// This is ideal for heavy computational tasks that would otherwise block
  /// the main isolate. It leverages [runTask] internally for queueing and retries.
  ///
  /// **Constraint**: The [task] must be a top-level function or a static method.
  /// Closures that capture state cannot be sent across isolate boundaries.
  ///
  /// [debugName] is an optional name for the isolate, visible in debug tools.
  Future<T?> runIsolateTask<T>(
    FutureOr<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    String? debugName,
  }) {
    return runTask(
      () => Isolate.run(task, debugName: debugName),
      id: id,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: onError,
      cachePolicy: cachePolicy,
    );
  }
}

/// A mixin for [LevitController] that combines task management with reactive state.
///
/// This mixin is ideal for controllers that drive UI needing to show loading states,
/// progress bars, or error messages for asynchronous operations.
///
/// It exposes:
/// *   [tasks]: A reactive map of task IDs to their current [LxStatus].
/// *   [totalProgress]: A computed value (0.0 to 1.0) representing overall progress.
mixin LevitReactiveTasksMixin on LevitController {
  late final _TaskEngine _reactiveTasksEngine;

  /// The maximum number of concurrent tasks allowed.
  int get maxConcurrentTasks => 100000;

  /// The maximum number of completed tasks to keep in history.
  ///
  /// Defaults to 50 to prevent unbounded memory growth.
  int get maxTaskHistory => 50;

  /// Optional delay before automatically removing a completed task.
  ///
  /// If null, tasks are kept until manually cleared or [maxTaskHistory] is reached.
  Duration? get autoCleanupDelay => null;

  /// A reactive map of task IDs to their current status.
  ///
  /// Use this to display the state of individual tasks in the UI.
  final tasks = LxMap<String, LxStatus<dynamic>>().named('tasks');

  /// Optional weights for individual tasks, used to calculate [totalProgress].
  final taskWeights = LxMap<String, double>().named('taskWeights');

  /// Reactive progress values (0.0 to 1.0) for active tasks.
  final taskProgress = LxMap<String, double>().named('taskProgress');

  /// Timers for auto-cleanup.
  final _cleanupTimers = <String, Timer>{};

  /// A computed value representing the weighted average progress (0.0 to 1.0) of all active tasks.
  ///
  /// **Warning:** This computation iterates over all active tasks. If you have hundreds
  /// of concurrent tasks, accessing this frequently triggers an O(N) loop.
  late final LxComputed<double> totalProgress;

  /// A computed value indicating if any tasks are currently active.
  late final LxComputed<bool> isBusy;

  /// Optional global error handler for tasks in this controller.
  void Function(Object error, StackTrace? stackTrace)? onTaskError;

  /// The cache provider used by this mixin.
  ///
  /// Defaults to an [InMemoryTaskCacheProvider]. Override this to provide
  /// a persistent storage implementation.
  LevitTaskCacheProvider get taskCacheProvider => _defaultCacheProvider;
  static final _defaultCacheProvider = InMemoryTaskCacheProvider();

  @override
  void onInit() {
    super.onInit();
    _reactiveTasksEngine = _TaskEngine(maxConcurrent: maxConcurrentTasks);

    // Initialize reactive state
    // Moved to field declaration to support implicit registration (constructor-phase capture)
    // Manually register for auto-disposal to support usage without DI/auto-registration
    autoDispose(tasks);
    autoDispose(taskWeights);
    autoDispose(taskProgress);

    totalProgress = (() {
      if (tasks.isEmpty) return 0.0;
      double sumProgress = 0;
      double sumWeight = 0;

      for (final id in tasks.keys) {
        final status = tasks[id]!;
        final weight = taskWeights[id] ?? 1.0;

        final p = switch (status) {
          LxSuccess() => 1.0,
          LxWaiting() => taskProgress[id] ?? 0.0,
          _ => 0.0,
        };

        sumProgress += p * weight;
        sumWeight += weight;
      }

      return sumWeight == 0 ? 0.0 : sumProgress / sumWeight;
    }).lx.named('totalProgress');

    isBusy = (() => tasks.values.any((s) => s is LxWaiting)).lx.named('isBusy');

    // Initialize reactive state
    // Manually register for auto-disposal to support usage without DI/auto-registration
    autoDispose(tasks);
    autoDispose(taskWeights);
    autoDispose(taskProgress);
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
    Future<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
  }) async {
    final taskId = id ?? _generateTaskId();

    if (cachePolicy != null) {
      final cacheKey = cachePolicy.key ?? taskId;
      final cachedJson = await taskCacheProvider.read(cacheKey);

      if (cachedJson != null) {
        final expiresAt =
            DateTime.fromMillisecondsSinceEpoch(cachedJson['expiresAt'] as int);
        if (DateTime.now().isBefore(expiresAt)) {
          final data = cachedJson['data'] as Map<String, dynamic>;
          try {
            final result = cachePolicy.fromJson(data);
            // Update reactive state for cache hit
            tasks[taskId] = LxSuccess<T>(result);
            _scheduleCleanup(taskId);
            return result;
          } catch (e) {
            // Deserialization fail
            await taskCacheProvider.delete(cacheKey);
          }
        } else {
          await taskCacheProvider.delete(cacheKey);
        }
      }
    }

    // Check for duplicate task ID
    if (tasks.containsKey(taskId) && tasks[taskId] is LxWaiting) {
      throw StateError('Task with id "$taskId" is already running. '
          'Use a unique ID or cancel the existing task first.');
    }

    _cleanupTimers[taskId]?.cancel();
    _cleanupTimers.remove(taskId);

    // Prune history
    if (tasks.length >= maxTaskHistory && !tasks.containsKey(taskId)) {
      // Find a completed/errored task to remove instead of just picking first
      final keyToRemove = tasks.keys.firstWhere(
        (k) => tasks[k] is! LxWaiting,
        orElse: () => '',
      );
      if (keyToRemove.isNotEmpty) {
        clearTask(keyToRemove);
      }
    }

    // Initialize status
    tasks[taskId] = LxWaiting<dynamic>();
    taskWeights[taskId] = weight;
    taskProgress[taskId] = 0.0;

    // Wrap execution to update UI state when it actually Runs
    Future<T> wrappedTask() async {
      try {
        final result = await task();
        tasks[taskId] = LxSuccess<T>(result);
        _scheduleCleanup(taskId);
        return result;
      } catch (e) {
        // Error handling is complex because the task engine catches it.
        // But we want to ensure cleanup hooks run if the engine doesn't invoke onError immediately?
        // Actually, engine catches it. The `onError` callback in `schedule` below handles it.
        rethrow;
      }
    }

    final result = await _reactiveTasksEngine.schedule(
      task: wrappedTask,
      id: taskId,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      onError: (e, s) {
        // This callback is invoked by engine only on FINAL failure
        tasks[taskId] = LxError<Object>(e, s, tasks[taskId]?.lastValue);
        final handler = onError ?? onTaskError;
        handler?.call(e, s);
        _scheduleCleanup(taskId);
      },
    );

    if (cachePolicy != null && result != null) {
      final cacheKey = cachePolicy.key ?? taskId;
      await taskCacheProvider.write(cacheKey, {
        'expiresAt': DateTime.now().add(cachePolicy.ttl).millisecondsSinceEpoch,
        'data': cachePolicy.toJson(result),
      });
    }

    return result;
  }

  void _scheduleCleanup(String id) {
    if (autoCleanupDelay == null) return;
    _cleanupTimers[id]?.cancel();
    _cleanupTimers[id] = Timer(autoCleanupDelay!, () {
      _cleanupTimers.remove(id);
      if (tasks.containsKey(id) && tasks[id] is! LxWaiting) {
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
      // tasks[id] = LxWaiting<dynamic>(current.lastValue); // Status doesn't change, just progress
      taskProgress[id] = value.clamp(0.0, 1.0);
    }
  }

  /// Clears a task from the state map and cancels it if running.
  void clearTask(String id) {
    tasks.remove(id);
    taskWeights.remove(id);
    taskProgress.remove(id);
    _cleanupTimers[id]?.cancel();
    _cleanupTimers.remove(id);
    cancelTask(id);
  }

  /// Clears all completed ([LxSuccess] or [AsyncIdle]) tasks from the state map.
  void clearCompleted() {
    final keys = tasks.keys
        .where((id) =>
            tasks[id] is LxSuccess ||
            tasks[id] is LxIdle ||
            tasks[id] is LxError)
        .toList();
    for (final id in keys) {
      clearTask(id);
    }
  }

  /// Cancels a specific task.
  void cancelTask(String id) => _reactiveTasksEngine.cancel(id);

  /// Cancels all tasks.
  void cancelAllTasks() => _reactiveTasksEngine.cancelAll();

  @override
  void onClose() {
    _reactiveTasksEngine.cancelAll();
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    // Reactive variables are closed by autoDispose
    super.onClose();
  }

  /// Executes a [task] in a separate [Isolate] using [Isolate.run].
  ///
  /// This is ideal for heavy computational tasks that would otherwise block
  /// the main isolate. It leverages [runTask] internally for queueing,
  /// reactive status tracking, and retries.
  ///
  /// **Constraint**: The [task] must be a top-level function or a static method.
  /// Closures that capture state cannot be sent across isolate boundaries.
  ///
  /// [debugName] is an optional name for the isolate, visible in debug tools.
  Future<T?> runIsolateTask<T>(
    FutureOr<T> Function() task, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    double weight = 1.0,
    void Function(Object error, StackTrace stackTrace)? onError,
    TaskCachePolicy<T>? cachePolicy,
    String? debugName,
  }) {
    return runTask(
      () => Isolate.run(task, debugName: debugName),
      id: id,
      priority: priority,
      retries: retries,
      retryDelay: retryDelay,
      useExponentialBackoff: useExponentialBackoff,
      weight: weight,
      onError: onError,
      cachePolicy: cachePolicy,
    );
  }
}

// ============================================================================
// Internal Task Engine
// ============================================================================

class _TaskEngine {
  final int maxConcurrent;
  final _activeTasks = <String, _ActiveTask>{};
  final _queue = <_QueuedTask>[];

  _TaskEngine({required this.maxConcurrent});

  Future<T?> schedule<T>({
    required String id,
    required Future<T> Function() task,
    required TaskPriority priority,
    required int retries,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    required Function(Object, StackTrace) onError,
  }) async {
    // If we can run now, run.
    if (_activeTasks.length < maxConcurrent) {
      return _execute<T>(
        id,
        task,
        retries,
        retryDelay,
        useExponentialBackoff,
        onError,
      );
    } else {
      // Enqueue
      final completer = Completer<T?>();
      _queue.add(_QueuedTask<T>(
        id: id,
        task: task,
        priority: priority,
        retries: retries,
        retryDelay: retryDelay,
        useExponentialBackoff: useExponentialBackoff,
        onError: onError,
        completer: completer,
      ));
      _sortQueue(); // Ensure highest priority is first
      return completer.future;
    }
  }

  void _sortQueue() {
    // Sort logic: High (0) < Normal (1) < Low (2). Min first.
    _queue.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  Future<T?> _execute<T>(
    String id,
    Future<T> Function() task,
    int retries,
    Duration? retryDelay,
    bool useExponentialBackoff,
    Function(Object, StackTrace) onError,
  ) async {
    // Track active task (stores cancel token logic if we implemented strictly, currently just marker)
    final activeTaskNode = _ActiveTask(id);
    _activeTasks[id] = activeTaskNode;

    int attempts = 0;
    while (true) {
      if (activeTaskNode.isCancelled) {
        _finalize(id);
        return null;
      }

      try {
        final result = await task();
        _finalize(id);
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
        } else {
          // Final failure
          _finalize(id);
          onError(e, s);
          // Return null to signify failure (since we handled it via onError)
          // Optionally rethrow if onError logic didn't stop propagation?
          // For now, we return null to match T? signature.
          return null;
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
      final next = _queue.removeAt(0); // Takes highest priority

      // Execute unwraps the dynamic-typed task closure from ScheduledTask
      // We need to cast or just run it. The completer handles the type.
      _runQueued(next);
    }
  }

  Future<void> _runQueued(_QueuedTask item) async {
    try {
      final result = await _execute(
        item.id,
        item.task,
        item.retries,
        item.retryDelay,
        item.useExponentialBackoff,
        item.onError,
      );
      item.completer.complete(result);
    } catch (e, s) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(e, s);
      }
    }
  }

  void cancel(String id) {
    if (_activeTasks.containsKey(id)) {
      _activeTasks[id]!.isCancelled = true;
      // We can't interrupt the Future, but the loop checks isCancelled before retry.
    }
    _queue.removeWhere((item) => item.id == id);
  }

  void cancelAll() {
    for (var t in _activeTasks.values) {
      t.isCancelled = true;
    }
    _queue.clear();
  }
}

class _ActiveTask {
  final String id;
  bool isCancelled = false;
  _ActiveTask(this.id);
}

class _QueuedTask<T> {
  final String id;
  final Future<T> Function() task;
  final TaskPriority priority;
  final int retries;
  final Duration? retryDelay;
  final bool useExponentialBackoff;
  final Function(Object, StackTrace) onError;
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
  });
}
