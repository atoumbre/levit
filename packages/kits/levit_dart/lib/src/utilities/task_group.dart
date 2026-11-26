part of '../kit_library.dart';

/// Controls how a [LevitTaskGroup] responds when one of its child tasks or
/// child groups fails.
///
/// Engine root groups use [supervisor] so independent top-level workflows do
/// not cancel one another.
///
/// {@category Tasks & Concurrency}
enum LevitTaskGroupPolicy {
  /// Cancels all sibling tasks and child groups as soon as one child fails.
  cancelOnError,

  /// Allows sibling tasks and child groups to continue running when one fails.
  supervisor,
}

/// Categorizes why a task execution or [LevitTaskGroup] was cancelled.
///
/// {@category Tasks & Concurrency}
enum LevitTaskCancellationKind {
  /// Cancellation was explicitly requested by calling `cancel()`.
  requested,

  /// The owning controller, engine, or scope began closing.
  ownerClosed,

  /// An enclosing parent [LevitTaskGroup] was cancelled.
  parentCancelled,

  /// A sibling failed in a [LevitTaskGroupPolicy.cancelOnError] group.
  siblingFailed,

  /// The task or group deadline expired.
  deadlineExceeded,

  /// A replacement submission superseded this execution (for example under
  /// [LevitTaskConflictPolicy.restart] or [LevitTaskConflictPolicy.coalesceLatest]).
  superseded,
}

/// Machine-readable cancellation metadata attached to cancelled tasks and
/// groups; cancellation signals a request and never implies completion.
///
/// {@category Tasks & Concurrency}
final class LevitTaskCancellationReason {
  /// The structured category describing why cancellation occurred.
  final LevitTaskCancellationKind kind;

  /// Optional human-readable diagnostic message.
  final String? message;

  /// Creates a cancellation reason with [kind] and optional [message].
  const LevitTaskCancellationReason(this.kind, [this.message]);

  @override
  String toString() => message == null ? kind.name : '${kind.name}: $message';
}

/// Retry schedule combining explicit error classification with bounded
/// exponential backoff and jitter.
///
/// ```dart
/// final retryPolicy = LevitRetryPolicy(
///   maxRetries: 3,
///   initialDelay: const Duration(milliseconds: 250),
///   maxDelay: const Duration(seconds: 10),
///   shouldRetry: (error, _) => error is TimeoutException,
/// );
/// ```
///
/// {@category Tasks & Concurrency}
final class LevitRetryPolicy {
  /// Maximum number of retry attempts after the initial attempt fails.
  final int maxRetries;

  /// Predicate returning `true` when `error` should be retried.
  final bool Function(Object error, StackTrace stack) shouldRetry;

  /// Base delay before the first retry attempt (defaults to 500 ms).
  final Duration initialDelay;

  /// Upper bound on computed retry delays (defaults to 30 seconds).
  final Duration maxDelay;

  /// Fractional jitter factor in `[0.0, 1.0]` applied symmetrically around the
  /// exponential delay (defaults to `0.2`).
  final double jitter;

  /// Creates a retry policy with explicit [shouldRetry] classification.
  ///
  /// Throws a [RangeError] if [maxRetries] < 0 or [jitter] is outside
  /// `[0.0, 1.0]`, or an [ArgumentError] if delays are negative or
  /// [initialDelay] exceeds [maxDelay].
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

  /// Computes the backoff delay for 1-based retry [attempt] (`initialDelay *
  /// 2^(attempt - 1)` capped at [maxDelay], adjusted by [jitter]).
  ///
  /// Supply [randomValue] in `[0.0, 1.0]` for deterministic testing.
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

/// Thrown synchronously when [LevitTaskEngine.maxPending] is reached and a new
/// submission cannot be queued.
///
/// {@category Tasks & Concurrency}
final class LevitTaskQueueFullException implements Exception {
  /// The configured pending queue capacity that was reached.
  final int capacity;

  /// Creates a queue-full exception recording [capacity].
  const LevitTaskQueueFullException(this.capacity);

  @override
  String toString() =>
      'Task queue has reached its $capacity pending submissions.';
}

/// Completed asynchronously on a task handle when a submission is ignored under
/// [LevitTaskConflictPolicy.drop].
///
/// {@category Tasks & Concurrency}
final class LevitTaskDroppedException implements Exception {
  /// The logical task ID whose submission was dropped.
  final String taskId;

  /// Creates a dropped-task exception for [taskId].
  const LevitTaskDroppedException(this.taskId);
}

/// Subtype of [LevitTaskCancelledException] thrown when an execution is
/// replaced under [LevitTaskConflictPolicy.restart] or
/// [LevitTaskConflictPolicy.coalesceLatest].
///
/// {@category Tasks & Concurrency}
final class LevitTaskSupersededException extends LevitTaskCancelledException {
  /// Creates a superseded-task exception with
  /// [LevitTaskCancellationKind.superseded].
  const LevitTaskSupersededException(super.taskId, super.executionId)
    : super(
        reason: const LevitTaskCancellationReason(
          LevitTaskCancellationKind.superseded,
        ),
      );
}

/// Sealed outcome union returned by [LevitTaskExecution.outcome] so callers can
/// exhaustively pattern-match terminal task states without catching exceptions.
///
/// {@category Tasks & Concurrency}
sealed class LevitTaskResult<T> {
  /// Creates a [LevitTaskResult].
  const LevitTaskResult();
}

/// Terminal [LevitTaskResult] representing successful completion with [value].
///
/// {@category Tasks & Concurrency}
final class LevitTaskSuccess<T> extends LevitTaskResult<T> {
  /// The value produced by the task (or served from cache).
  final T value;

  /// Creates a success result holding [value].
  const LevitTaskSuccess(this.value);
}

/// Terminal [LevitTaskResult] representing an unhandled task failure.
///
/// {@category Tasks & Concurrency}
final class LevitTaskFailure<T> extends LevitTaskResult<T> {
  /// The error thrown by the task.
  final Object error;

  /// The stack trace captured with [error].
  final StackTrace stackTrace;

  /// Creates a failure result holding [error] and [stackTrace].
  const LevitTaskFailure(this.error, this.stackTrace);
}

/// Terminal [LevitTaskResult] representing cooperative cancellation.
///
/// {@category Tasks & Concurrency}
final class LevitTaskCancelled<T> extends LevitTaskResult<T> {
  /// The structured reason describing why cancellation occurred.
  final LevitTaskCancellationReason reason;

  /// Creates a cancelled result with [reason].
  const LevitTaskCancelled(this.reason);
}

/// Terminal [LevitTaskResult] indicating a submission was ignored under
/// [LevitTaskConflictPolicy.drop].
///
/// {@category Tasks & Concurrency}
final class LevitTaskDropped<T> extends LevitTaskResult<T> {
  /// Creates a dropped result.
  const LevitTaskDropped();
}

/// Terminal [LevitTaskResult] indicating an execution was replaced under
/// [LevitTaskConflictPolicy.restart] or
/// [LevitTaskConflictPolicy.coalesceLatest].
///
/// {@category Tasks & Concurrency}
final class LevitTaskSuperseded<T> extends LevitTaskResult<T> {
  /// Creates a superseded result.
  const LevitTaskSuperseded();
}

/// Aggregate exception thrown by [LevitTaskGroup.run] or
/// [LevitTaskGroup.dispose] when one or more failures occurred within the group.
///
/// {@category Tasks & Concurrency}
final class LevitTaskGroupException implements Exception {
  /// Unmodifiable list of failures collected from the group body and children.
  final List<AsyncError> failures;

  /// Creates a group exception containing [failures].
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

/// A structured-concurrency coordination boundary for tasks and child groups.
///
/// Group bodies and child groups do not occupy worker slots on [engine] — only
/// submitted leaf tasks do. Always await child group bodies so work settles
/// inside the enclosing boundary.
///
/// ```dart
/// final summary = await controller.taskGroup.runGroup((group) async {
///   final user = group.schedule((ctx) => api.fetchUser(id));
///   final prefs = group.schedule((ctx) => api.fetchPrefs(id));
///   return (await user, await prefs);
/// }, name: 'load_profile');
/// ```
///
/// {@category Tasks & Concurrency}
final class LevitTaskGroup
    implements LevitDrainable, LevitDisposable, LevitExecutionBoundary {
  static int _nextId = 0;

  /// The currently executing [LevitTaskGroup] in this [Zone], if any.
  static LevitTaskGroup? get current => _currentTaskZone?.group;

  /// Unique runtime identifier for this group.
  final String id;

  /// Diagnostic name for this group.
  final String name;

  /// The [LevitTaskEngine] executing tasks admitted into this group.
  final LevitTaskEngine engine;

  /// The parent group, or `null` for an engine's root group.
  final LevitTaskGroup? parent;

  /// Sibling failure policy ([LevitTaskGroupPolicy.cancelOnError] or
  /// [LevitTaskGroupPolicy.supervisor]).
  final LevitTaskGroupPolicy policy;

  /// Effective absolute deadline, clamped to the earliest ancestor deadline.
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
            LevitTaskCancellationKind.deadlineExceeded,
          ),
        ),
      );
    }
  }

  /// Creates a child group under [parent], the active [current] group on
  /// [engine], or `engine.rootGroup`.
  ///
  /// [name] defaults to `'workflow'` and [policy] defaults to
  /// [LevitTaskGroupPolicy.cancelOnError]. If [deadline] is provided, it is
  /// clamped to the parent's deadline. Throws an [ArgumentError] if [parent]
  /// belongs to a different engine.
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

  /// Whether cancellation has been requested for this group.
  bool get isCancelled => _cancellation.isCancelled;

  /// Whether this group has sealed admissions or been cancelled.
  bool get isClosing => _sealed || isCancelled;

  /// Whether the group body, all submitted tasks, and all child groups have
  /// finished.
  bool get isComplete => _complete;

  /// Structured reason for cancellation, or `null` if not cancelled.
  LevitTaskCancellationReason? get cancellationReason => _cancellation.reason;

  /// Completes when cancellation is requested on this group.
  Future<void> get cancelled => _cancellation.cancelled;

  /// Terminal completion signal. Await [run] or [dispose] to observe failures.
  Future<void> get done => _done.future;

  void _ensureAdmission() {
    engine._ensureUsable();
    if (_sealed || _complete || isCancelled)
      throw StateError('Task group $name is closing.');
    if (deadline != null && !DateTime.now().isBefore(deadline!)) {
      cancel(
        const LevitTaskCancellationReason(
          LevitTaskCancellationKind.deadlineExceeded,
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
        const LevitTaskCancellationReason(
          LevitTaskCancellationKind.siblingFailed,
        ),
      );
    }
  }

  /// Runs one workflow [body] and waits for every admitted task and child group
  /// to settle (including `finally` blocks).
  ///
  /// May only be called once on a fresh non-root group outside any leaf task
  /// running on [engine] (otherwise throws [StateError]). Throws
  /// [LevitTaskGroupException] if failures occurred, or
  /// [LevitTaskCancelledException] if cancelled.
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
  }) {
    if (identical(_currentTaskZone?.execution?.config.group.engine, engine)) {
      return Future<T>.error(
        StateError(
          'Coordinate groups outside a leaf task; submit leaves from the group body.',
        ),
      );
    }
    return LevitTaskGroup(
      engine: engine,
      parent: this,
      name: name,
      policy: policy,
      deadline: deadline,
    ).run(body);
  }

  /// Submits a leaf task to [engine] owned by this group and returns its
  /// [LevitTaskExecution] handle.
  LevitTaskExecution<T> submit<T>(
    FutureOr<T> Function(LevitTaskContext) body, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    DateTime? deadline,
    LevitTaskCachePolicy<T>? cachePolicy,
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

  /// Schedules a leaf task in this group and returns its eventual result
  /// [Future] (shorthand for `submit(...).result`).
  Future<T> schedule<T>(
    FutureOr<T> Function(LevitTaskContext) body, {
    String? id,
    LevitTaskPriority priority = LevitTaskPriority.normal,
    LevitTaskConflictPolicy conflictPolicy = LevitTaskConflictPolicy.reject,
    LevitRetryPolicy? retryPolicy,
    DateTime? deadline,
    LevitTaskCachePolicy<T>? cachePolicy,
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

  /// Cooperatively cancels this group, every child group, and every admitted
  /// task using [reason].
  void cancel([
    LevitTaskCancellationReason reason = const LevitTaskCancellationReason(
      LevitTaskCancellationKind.requested,
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
        LevitTaskSkipReason.cancelledWhileQueued,
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

  /// Throws a [StateError] if called from inside a running leaf task on
  /// [engine] or from inside this group's own active [run] body.
  @override
  void assertCanDispose() {
    if (identical(_currentTaskZone?.execution?.config.group.engine, engine)) {
      throw StateError(
        'Tracked work cannot await disposal of its own engine or owner.',
      );
    }
    var active = current;
    while (active != null) {
      if (identical(active, this) && active._bodyRunning)
        throw StateError('A group body cannot dispose its own group.');
      active = active.parent;
    }
  }

  /// Requests cooperative cancellation of this group and its descendants.
  @override
  void requestCancel() => cancel();

  /// Cancels this group and waits until [done] completes.
  @override
  Future<void> drain() async {
    assertCanDispose();
    requestCancel();
    await done;
  }

  /// Cancels this group, waits for all descendants to settle, and throws
  /// [LevitTaskGroupException] if any failures occurred.
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

/// Immutable, value-free snapshot of a live [LevitTaskGroup] tree.
///
/// Completed executions remain available through [LevitTaskTracker] or
/// [LevitTaskMiddleware] instead of accumulating here.
///
/// {@category Tasks & Concurrency}
final class LevitTaskTreeSnapshot {
  /// Unique group identifier.
  final String id;

  /// Human-readable group name.
  final String name;

  /// Parent group identifier, or `null` for the root group.
  final String? parentId;

  /// Whether this group is closing or cancelled.
  final bool isClosing;

  /// Whether this group and all its descendants have completed.
  final bool isComplete;

  /// Effective absolute deadline for this group, if any.
  final DateTime? deadline;

  /// Cancellation reason, if this group was cancelled.
  final LevitTaskCancellationReason? cancellationReason;

  /// Number of queued leaf tasks directly inside this group.
  final int pendingCount;

  /// Number of running leaf tasks directly inside this group.
  final int runningCount;

  /// Unmodifiable list of active execution IDs directly inside this group.
  final List<String> executionIds;

  /// Unmodifiable list of child group snapshots.
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
