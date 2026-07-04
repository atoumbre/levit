part of '../../levit_dart.dart';

Queue<_QueuedTask> _queueForPriority({
  required TaskPriority priority,
  required Queue<_QueuedTask> highPriorityQueue,
  required Queue<_QueuedTask> normalPriorityQueue,
  required Queue<_QueuedTask> lowPriorityQueue,
}) {
  switch (priority) {
    case TaskPriority.high:
      return highPriorityQueue;
    case TaskPriority.normal:
      return normalPriorityQueue;
    case TaskPriority.low:
      return lowPriorityQueue;
  }
}

bool _hasQueuedTasksInQueues({
  required Queue<_QueuedTask> highPriorityQueue,
  required Queue<_QueuedTask> normalPriorityQueue,
  required Queue<_QueuedTask> lowPriorityQueue,
}) {
  return highPriorityQueue.isNotEmpty ||
      normalPriorityQueue.isNotEmpty ||
      lowPriorityQueue.isNotEmpty;
}

_QueuedTask? _takeNextQueuedTaskFromQueues({
  required Queue<_QueuedTask> highPriorityQueue,
  required Queue<_QueuedTask> normalPriorityQueue,
  required Queue<_QueuedTask> lowPriorityQueue,
}) {
  if (highPriorityQueue.isNotEmpty) return highPriorityQueue.removeFirst();
  if (normalPriorityQueue.isNotEmpty) return normalPriorityQueue.removeFirst();
  if (lowPriorityQueue.isNotEmpty) return lowPriorityQueue.removeFirst();
  return null;
}

void _cancelQueuedTask(
  _QueuedTask item, {
  required void Function(LevitTaskEvent event) emitTaskEvent,
}) {
  item.onCancel?.call();
  emitTaskEvent(LevitTaskEvent(
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

void _cancelQueuedByIdInQueue(
  Queue<_QueuedTask> queue,
  String id, {
  required void Function(LevitTaskEvent event) emitTaskEvent,
}) {
  if (queue.isEmpty) return;

  final retained = Queue<_QueuedTask>();
  for (final item in queue) {
    if (item.id == id) {
      _cancelQueuedTask(item, emitTaskEvent: emitTaskEvent);
    } else {
      retained.add(item);
    }
  }
  queue
    ..clear()
    ..addAll(retained);
}

void _cancelAllQueuedInQueue(
  Queue<_QueuedTask> queue, {
  required void Function(LevitTaskEvent event) emitTaskEvent,
}) {
  for (final item in queue) {
    _cancelQueuedTask(item, emitTaskEvent: emitTaskEvent);
  }
  queue.clear();
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
