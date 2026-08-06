part of '../../levit_dart.dart';

enum _TaskExecutionState { queued, running, completed }

enum _IsolateTaskMessage {
  cancellationPort,
  progress,
  success,
  error,
}

class _TaskExecutionConfig {
  FutureOr<dynamic> Function(LevitTaskContext context) task;
  TaskPriority priority;
  int retries;
  Duration? retryDelay;
  bool useExponentialBackoff;
  void Function(Object, StackTrace)? onError;
  dynamic cachePolicy;
  void Function()? onStart;
  void Function(dynamic result)? onSuccess;
  void Function(double progress)? onProgress;
  void Function()? onCancel;
  void Function(LevitTaskEvent event)? onEvent;
  LevitTaskMetadata metadata;
  bool runsInIsolate;

  _TaskExecutionConfig({
    required this.task,
    required this.priority,
    required this.retries,
    required this.retryDelay,
    required this.useExponentialBackoff,
    required this.onError,
    required this.cachePolicy,
    required this.onStart,
    required this.onSuccess,
    required this.onProgress,
    required this.onCancel,
    required this.onEvent,
    required this.metadata,
    required this.runsInIsolate,
  });
}

class _TaskExecution {
  final String taskId;
  final String executionId;
  final String ownerPath;
  final DateTime queuedAt;
  final Completer<dynamic> completer = Completer<dynamic>();
  final _LevitTaskCancellation cancellation = _LevitTaskCancellation();

  _TaskExecutionConfig config;
  _TaskExecutionState state = _TaskExecutionState.queued;
  DateTime? startedAt;
  int attempt = 0;
  double progress = 0;
  bool detachedByRestart = false;
  TaskSkipReason? cancellationReason;

  _TaskExecution({
    required this.taskId,
    required this.executionId,
    required this.ownerPath,
    required this.queuedAt,
    required this.config,
  });
}

class _TaskGroup {
  final String taskId;
  final List<_TaskExecution> outstanding = [];
  _TaskExecution? coalescedTail;

  _TaskGroup(this.taskId);

  _TaskExecution? get latest => outstanding.isEmpty ? null : outstanding.last;
}

Queue<_TaskExecution> _queueForPriority({
  required TaskPriority priority,
  required Queue<_TaskExecution> highPriorityQueue,
  required Queue<_TaskExecution> normalPriorityQueue,
  required Queue<_TaskExecution> lowPriorityQueue,
}) {
  return switch (priority) {
    TaskPriority.high => highPriorityQueue,
    TaskPriority.normal => normalPriorityQueue,
    TaskPriority.low => lowPriorityQueue,
  };
}
