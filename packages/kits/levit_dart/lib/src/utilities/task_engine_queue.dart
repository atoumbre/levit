part of '../kit_library.dart';

enum _TaskExecutionState { queued, running, completed }

enum _IsolateTaskMessage {
  cancellationPort,
  cancelled,
  progress,
  success,
  error,
}

class _TaskExecutionConfig {
  FutureOr<dynamic> Function(LevitTaskContext context) task;
  LevitTaskPriority priority;
  LevitRetryPolicy? retryPolicy;
  LevitTaskGroup group;
  DateTime? deadline;
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
    required this.retryPolicy,
    required this.group,
    required this.deadline,
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
  final Object schedulingKey;
  Timer? deadlineTimer;
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
  bool inPriorityQueue = false;
  LevitTaskSkipReason? cancellationReason;
  LevitDisposalFailure? cleanupFailure;

  _TaskExecution({
    required this.taskId,
    required this.schedulingKey,
    required this.executionId,
    required this.ownerPath,
    required this.queuedAt,
    required this.config,
  });
}

class _TaskGroup {
  final Object key;
  final ListQueue<_TaskExecution> outstanding = ListQueue<_TaskExecution>();
  _TaskExecution? coalescedTail;

  _TaskGroup(this.key);

  _TaskExecution? get latest => outstanding.isEmpty ? null : outstanding.last;
}

Queue<_TaskExecution> _queueForPriority({
  required LevitTaskPriority priority,
  required Queue<_TaskExecution> highPriorityQueue,
  required Queue<_TaskExecution> normalPriorityQueue,
  required Queue<_TaskExecution> lowPriorityQueue,
}) {
  return switch (priority) {
    LevitTaskPriority.high => highPriorityQueue,
    LevitTaskPriority.normal => normalPriorityQueue,
    LevitTaskPriority.low => lowPriorityQueue,
  };
}
