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
