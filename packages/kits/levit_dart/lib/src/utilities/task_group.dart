part of '../../levit_dart.dart';

/// Sibling failure behavior. Controller roots supervise unrelated work.
enum LevitTaskGroupPolicy { cancelOnError, supervisor }

enum LevitCancellationKind {
  requested,
  ownerClosed,
  parentCancelled,
  siblingFailed,
  deadlineExceeded,
  superseded,
}

/// Machine-readable cancellation metadata; cancellation never implies completion.
final class LevitTaskCancellationReason {
  final LevitCancellationKind kind;
  final String? message;
  const LevitTaskCancellationReason(this.kind, [this.message]);
  @override
  String toString() => message == null ? kind.name : '${kind.name}: $message';
}

/// Explicit error classification with bounded exponential retry delays.
final class LevitRetryPolicy {
  final int maxRetries;
  final bool Function(Object error, StackTrace stack) shouldRetry;
  final Duration initialDelay;
  final Duration maxDelay;
  final double jitter;
  LevitRetryPolicy({
    required this.shouldRetry,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = 0.2,
  }) {
    if (maxRetries < 0) throw RangeError.value(maxRetries, 'maxRetries');
    if (initialDelay.isNegative ||
        maxDelay.isNegative ||
        initialDelay > maxDelay) {
      throw ArgumentError(
        'Retry delays must be nonnegative and capped by maxDelay.',
      );
    }
    if (!jitter.isFinite || jitter < 0 || jitter > 1)
      throw RangeError.range(jitter, 0, 1, 'jitter');
  }
  Duration delayFor(int attempt, {double? randomValue}) {
    final capped = math.min(
      maxDelay.inMicroseconds.toDouble(),
      initialDelay.inMicroseconds *
          math.pow(2, math.min(52, math.max(0, attempt - 1))),
    );
    final random = randomValue ?? math.Random().nextDouble();
    final micros = (capped * (1 - jitter + 2 * jitter * random)).round();
    return Duration(microseconds: micros.clamp(0, maxDelay.inMicroseconds));
  }
}

final class LevitTaskQueueFullException implements Exception {
  final int capacity;
  const LevitTaskQueueFullException(this.capacity);
  @override
  String toString() =>
      'Task queue has reached its $capacity pending submissions.';
}

final class LevitTaskDroppedException implements Exception {
  final String taskId;
  const LevitTaskDroppedException(this.taskId);
}

final class LevitTaskSupersededException extends LevitTaskCancelledException {
  const LevitTaskSupersededException(super.taskId, super.executionId)
    : super(
        reason: const LevitTaskCancellationReason(
          LevitCancellationKind.superseded,
        ),
      );
}

sealed class LevitExecutionOutcome<T> {
  const LevitExecutionOutcome();
}

final class LevitTaskSuccess<T> extends LevitExecutionOutcome<T> {
  final T value;
  const LevitTaskSuccess(this.value);
}

final class LevitTaskFailure<T> extends LevitExecutionOutcome<T> {
  final Object error;
  final StackTrace stackTrace;
  const LevitTaskFailure(this.error, this.stackTrace);
}

final class LevitTaskCancellation<T> extends LevitExecutionOutcome<T> {
  final LevitTaskCancellationReason reason;
  const LevitTaskCancellation(this.reason);
}

final class LevitTaskDropping<T> extends LevitExecutionOutcome<T> {
  const LevitTaskDropping();
}

final class LevitTaskSupersession<T> extends LevitExecutionOutcome<T> {
  const LevitTaskSupersession();
}

final class LevitTaskGroupException implements Exception {
  final List<AsyncError> failures;
  LevitTaskGroupException(Iterable<AsyncError> failures)
    : failures = List.unmodifiable(failures);
  @override
  String toString() =>
      'LevitTaskGroupException(${failures.map((error) => error.error).join('; ')})';
}

DateTime? _earliestDeadline(DateTime? a, DateTime? b) => a == null
    ? b
    : b == null
    ? a
    : a.isBefore(b)
    ? a
    : b;

/// A coordination boundary. Its body and child groups do not occupy worker slots;
/// only submitted leaf tasks do. Always return/await child group bodies.
final class LevitTaskGroup
    implements LevitDrainable, LevitDisposable, LevitExecutionBoundary {
  static int _nextId = 0;
  static LevitTaskGroup? get current => _currentTaskZone?.group;
  final String id;
  final String name;
  final LevitTaskEngine engine;
  final LevitTaskGroup? parent;
  final LevitTaskGroupPolicy policy;
  final DateTime? deadline;
  final Set<LevitTaskGroup> _children = {};
  final Set<_TaskExecution> _tasks = {};
  final List<AsyncError> _failures = [];
  final _LevitTaskCancellation _cancellation = _LevitTaskCancellation();
  final Completer<void> _done = Completer<void>();
  final bool _root;
  Timer? _deadlineTimer;
  bool _bodyStarted = false;
  bool _bodyRunning = false;
  bool _sealed = false;
  bool _complete = false;

  LevitTaskGroup._(
    this.engine,
    this.parent, {
    required this.name,
    required this.policy,
    DateTime? deadline,
    bool root = false,
  }) : id = 'group_${_nextId++}',
       _root = root,
       deadline = _earliestDeadline(deadline, parent?.deadline) {
    parent?._admitChild(this);
    if (this.deadline case final limit?) {
      _deadlineTimer = Timer(
        limit.difference(DateTime.now()),
        () => cancel(
          const LevitTaskCancellationReason(
            LevitCancellationKind.deadlineExceeded,
          ),
        ),
      );
    }
  }

  /// Creates a child of [parent], the current group, or the engine's root.
  factory LevitTaskGroup({
    required LevitTaskEngine engine,
    LevitTaskGroup? parent,
    String name = 'workflow',
    LevitTaskGroupPolicy policy = LevitTaskGroupPolicy.cancelOnError,
    DateTime? deadline,
  }) {
    final owner =
        parent ??
        (identical(current?.engine, engine) ? current : null) ??
        engine.rootGroup;
    if (!identical(owner.engine, engine))
      throw ArgumentError('Parent and child must use the same engine.');
    return LevitTaskGroup._(
      engine,
      owner,
      name: name,
      policy: policy,
      deadline: deadline,
    );
  }

  bool get isCancelled => _cancellation.isCancelled;
  bool get isClosing => _sealed || isCancelled;
  bool get isComplete => _complete;
  LevitTaskCancellationReason? get cancellationReason => _cancellation.reason;
  Future<void> get cancelled => _cancellation.cancelled;

  /// Terminal completion signal. Await [run] or [dispose] for failures.
  Future<void> get done => _done.future;

  void _ensureAdmission() {
    engine._ensureUsable();
    if (_sealed || _complete || isCancelled)
      throw StateError('Task group $name is closing.');
    if (deadline != null && !DateTime.now().isBefore(deadline!)) {
      cancel(
        const LevitTaskCancellationReason(
          LevitCancellationKind.deadlineExceeded,
        ),
      );
      throw LevitTaskCancelledException(name, id, reason: cancellationReason!);
    }
  }

  void _admitChild(LevitTaskGroup child) {
    _ensureAdmission();
    _children.add(child);
    engine._notifyTaskTree();
  }

  void _admitTask(_TaskExecution task) {
    _ensureAdmission();
    _tasks.add(task);
  }

  void _taskFinished(_TaskExecution task, [Object? error, StackTrace? stack]) {
    _tasks.remove(task);
    if (error != null &&
        error is! LevitTaskCancelledException &&
        error is! LevitTaskDroppedException) {
      _failed(error, stack ?? StackTrace.current);
    }
    _checkComplete();
    engine._notifyTaskTree();
  }

  void _failed(Object error, StackTrace stack) {
    if (_root) return; // Root failures belong to the individual result/outcome.
    _failures.add(AsyncError(error, stack));
    if (policy == LevitTaskGroupPolicy.cancelOnError) {
      cancel(
        const LevitTaskCancellationReason(LevitCancellationKind.siblingFailed),
      );
    }
  }

  /// Runs one workflow body and waits for every descendant, including finally.
  Future<T> run<T>(FutureOr<T> Function(LevitTaskGroup group) body) async {
    _ensureAdmission();
    if (_root || _bodyStarted)
      throw StateError('Run a fresh child workflow group once.');
    if (identical(_currentTaskZone?.execution?.config.group.engine, engine)) {
      throw StateError(
        'Coordinate groups outside a leaf task; submit leaves from the group body.',
      );
    }
    _bodyStarted = true;
    _bodyRunning = true;
    late T result;
    try {
      result = await runZoned(
        () => body(this),
        zoneValues: {
          _taskZoneKey: (group: this, execution: _currentTaskZone?.execution),
        },
      );
    } catch (error, stack) {
      if (error is LevitTaskCancelledException) {
        cancel(error.reason);
      } else {
        _failed(error, stack);
      }
    } finally {
      _bodyRunning = false;
      _seal();
    }
    await done;
    if (_failures.isNotEmpty) throw LevitTaskGroupException(_failures);
    if (isCancelled)
      throw LevitTaskCancelledException(name, id, reason: cancellationReason!);
    return result;
  }

  /// Convenience for a nested coordination body; no execution slot is consumed.
  Future<T> runGroup<T>(
    FutureOr<T> Function(LevitTaskGroup) body, {
    String name = 'workflow',
    LevitTaskGroupPolicy policy = LevitTaskGroupPolicy.cancelOnError,
    DateTime? deadline,
  }) => LevitTaskGroup(
    engine: engine,
    parent: this,
    name: name,
    policy: policy,
    deadline: deadline,
  ).run(body);

  LevitTaskExecution<T> submit<T>(
    FutureOr<T> Function(LevitTaskContext) body, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    DateTime? deadline,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
  }) => engine.submit(
    body,
    group: this,
    id: id,
    priority: priority,
    conflictPolicy: conflictPolicy,
    retryPolicy: retryPolicy,
    deadline: deadline,
    cachePolicy: cachePolicy,
    metadata: metadata,
  );

  Future<T> schedule<T>(
    FutureOr<T> Function(LevitTaskContext) body, {
    String? id,
    TaskPriority priority = TaskPriority.normal,
    TaskConflictPolicy conflictPolicy = TaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    DateTime? deadline,
    TaskCachePolicy<T>? cachePolicy,
    LevitTaskMetadata? metadata,
  }) => submit(
    body,
    id: id,
    priority: priority,
    conflictPolicy: conflictPolicy,
    retryPolicy: retryPolicy,
    deadline: deadline,
    cachePolicy: cachePolicy,
    metadata: metadata,
  ).result;

  void cancel([
    LevitTaskCancellationReason reason = const LevitTaskCancellationReason(
      LevitCancellationKind.requested,
    ),
  ]) {
    if (_complete || isCancelled) return;
    _cancellation.cancel(reason);
    for (final child in _children.toList()) {
      child.cancel(reason);
    }
    for (final task in _tasks.toList()) {
      engine._cancelExecution(
        task,
        TaskSkipReason.cancelledWhileQueued,
        reason: reason,
      );
    }
    _sealed = true;
    _checkComplete();
    engine._notifyTaskTree();
  }

  void _seal() {
    _sealed = true;
    for (final child in _children.toList()) {
      if (!child._bodyStarted) child._seal();
    }
    _checkComplete();
  }

  void _checkComplete() {
    if (_complete ||
        !_sealed ||
        _bodyRunning ||
        _tasks.isNotEmpty ||
        _children.isNotEmpty)
      return;
    _complete = true;
    _deadlineTimer?.cancel();
    _done.complete();
    final owner = parent;
    if (owner != null) {
      owner._children.remove(this);
      // A supervisor root observes errors in individual workflow results.
      if (!_root &&
          _failures.isNotEmpty &&
          owner.policy == LevitTaskGroupPolicy.cancelOnError) {
        owner._failed(LevitTaskGroupException(_failures), StackTrace.current);
      }
      owner._checkComplete();
    }
    engine._notifyTaskTree();
  }

  @override
  void assertCanDispose() {
    engine.assertCanDispose();
    var active = current;
    while (active != null) {
      if (identical(active, this) && active._bodyRunning)
        throw StateError('A group body cannot dispose its own group.');
      active = active.parent;
    }
  }

  @override
  void requestCancel() => cancel();
  @override
  Future<void> drain() async {
    assertCanDispose();
    await done;
  }

  @override
  Future<void> dispose() async {
    assertCanDispose();
    cancel();
    await done;
    if (_failures.isNotEmpty) throw LevitTaskGroupException(_failures);
  }
}

final Object _taskZoneKey = Object();
typedef _TaskZone = ({LevitTaskGroup group, _TaskExecution? execution});
_TaskZone? get _currentTaskZone => Zone.current[_taskZoneKey] as _TaskZone?;

/// Immutable, value-free live task tree. Completed executions remain available
/// through the bounded task tracker/event stream instead of accumulating here.
final class LevitTaskTreeSnapshot {
  final String id;
  final String name;
  final String? parentId;
  final bool isClosing;
  final bool isComplete;
  final DateTime? deadline;
  final LevitTaskCancellationReason? cancellationReason;
  final int pendingCount;
  final int runningCount;
  final List<String> executionIds;
  final List<LevitTaskTreeSnapshot> children;
  LevitTaskTreeSnapshot._(LevitTaskGroup group)
    : id = group.id,
      name = group.name,
      parentId = group.parent?.id,
      isClosing = group.isClosing,
      isComplete = group.isComplete,
      deadline = group.deadline,
      cancellationReason = group.cancellationReason,
      pendingCount = group._tasks
          .where((task) => task.state == _TaskExecutionState.queued)
          .length,
      runningCount = group._tasks
          .where((task) => task.state == _TaskExecutionState.running)
          .length,
      executionIds = List.unmodifiable(
        group._tasks.map((task) => task.executionId),
      ),
      children = List.unmodifiable(
        group._children.map(LevitTaskTreeSnapshot._),
      );
}
