# Structured Concurrency for Levit Tasks

This document proposes the next iteration of `levit_dart` task orchestration.
It is a design note, not an implemented API contract.

## Why this exists

`LevitTaskEngine`, `LevitTasksMixin`, and `LevitReactiveTasksMixin` already provide:

- Concurrency limits.
- Priority queues.
- Retries with backoff.
- Cancellation by task id.
- Reactive task status for UI and runtime observation.

What they do not provide yet is structure.

Today tasks are flat:

- A controller can cancel one task or all tasks.
- There is no parent-child task relationship.
- There is no inherited deadline.
- There is no group failure policy.
- Async ownership ends at "this controller owns one engine".

That is useful, but it is weaker than the rest of Levit's ownership model.
Levit scopes own controllers, controllers own reactive resources, and disposal is explicit.
Tasks should follow the same pattern: a parent task group should own all descendant work.

## Goals

- Preserve controller-owned task cleanup.
- Add parent-child cancellation trees.
- Add inherited deadlines.
- Add group-level failure policy.
- Keep the current `schedule(...)` and `runTask(...)` APIs working during migration.
- Make group state observable from `LevitReactiveTasksMixin`.

## Non-goals

- Hard-cancel arbitrary Dart futures.
- Replace the existing queueing engine in one step.
- Require Flutter-specific APIs.
- Turn task orchestration into a codegen-only feature.

Cancellation remains cooperative. Descendants can be marked cancelled immediately, but already running work must observe the cancellation context to stop early.

## Proposed Model

The new model introduces a task tree:

- Every controller with `LevitTasksMixin` or `LevitReactiveTasksMixin` owns a root task group.
- A task group can run child tasks.
- A task group can create child task groups.
- Cancelling a group cancels all queued and running descendants.
- Deadlines and cancellation policy flow downward unless overridden.

In practice:

- `LevitController` owns cleanup.
- The root `LevitTaskGroup` is controller-owned.
- Child groups own sub-workflows.
- Leaf tasks are the units that actually enter the engine queue.

## Proposed Public API

### Core Types

```dart
typedef LevitTaskAction<T> = FutureOr<T> Function(LevitTaskContext context);
typedef LevitTaskGroupAction<T> = FutureOr<T> Function(LevitTaskGroup group);

enum LevitTaskFailurePolicy {
  cancelOnError,
  supervisor,
}

enum LevitTaskCancellationReason {
  explicit,
  parentCancelled,
  deadlineExceeded,
  controllerClosed,
  groupFailure,
}

abstract interface class LevitTaskContext {
  String get id;
  String get path;
  DateTime? get deadline;
  bool get isCancelled;
  LevitTaskCancellationReason? get cancellationReason;

  void throwIfCancelled();
  void reportProgress(double value);
}

abstract interface class LevitTaskGroup implements LevitDisposable {
  String get id;
  String get path;
  LevitTaskGroup? get parent;
  DateTime? get deadline;
  bool get isCancelled;
  bool get isClosed;
  LevitTaskFailurePolicy get failurePolicy;

  Future<T?> run<T>(
    String id,
    LevitTaskAction<T> task, {
    TaskPriority priority = TaskPriority.normal,
    int retries = 0,
    Duration? retryDelay,
    bool useExponentialBackoff = true,
    Duration? timeout,
    DateTime? deadline,
    void Function(Object error, StackTrace stackTrace)? onError,
    String? debugName,
  });

  Future<T?> group<T>(
    String id,
    LevitTaskGroupAction<T> action, {
    LevitTaskFailurePolicy? failurePolicy,
    Duration? timeout,
    DateTime? deadline,
    String? debugName,
  });

  void cancel([LevitTaskCancellationReason reason =
      LevitTaskCancellationReason.explicit]);
}
```

### Mixin Surface

```dart
mixin LevitTasksMixin on LevitController {
  LevitTaskEngine get tasksEngine;
  LevitTaskGroup get taskRoot;
}

mixin LevitReactiveTasksMixin on LevitController {
  LevitTaskEngine get tasksEngine;
  LevitTaskGroup get taskRoot;

  LxMap<String, TaskDetails> get tasks;
  LxMap<String, TaskGroupDetails> get taskGroups;
}
```

### Example

```dart
class SyncController extends LevitController with LevitReactiveTasksMixin {
  Future<void> syncProject(String projectId) async {
    await taskRoot.group(
      'syncProject',
      (group) async {
        final project = await group.run(
          'project',
          (task) async {
            task.throwIfCancelled();
            return api.fetchProject(projectId);
          },
        );

        if (project == null) return;

        await group.group('assets', (assets) async {
          await Future.wait([
            assets.run('cover', (task) => api.fetchCover(project.coverId)),
            assets.run('members', (task) => api.fetchMembers(project.id)),
          ]);
        });
      },
      deadline: DateTime.now().add(const Duration(seconds: 10)),
      failurePolicy: LevitTaskFailurePolicy.cancelOnError,
    );
  }
}
```

## Ownership Semantics

### Root ownership

The controller owns one root task group:

- It is created in `onInit()`.
- It is cancelled in `onClose()`.
- It should be registered through existing controller cleanup so close semantics stay centralized.

That preserves the current rule: when a controller closes, its async work becomes invalid.

### Group ownership

A group owns:

- Its child groups.
- Its leaf tasks.
- Its inherited deadline.
- Its failure policy.

When a group closes or is cancelled, all descendants are cancelled with `parentCancelled` or `groupFailure`.

## Cancellation Semantics

Cancellation is cooperative and tree-shaped:

- Cancelling a queued task removes it from the queue immediately.
- Cancelling a running task marks its context cancelled immediately.
- A task can stop early by checking `context.isCancelled` or calling `context.throwIfCancelled()`.
- If a running task ignores cancellation, its result is discarded when it completes.

This keeps Levit honest about what Dart futures can and cannot do.

## Deadline Semantics

Deadlines should be absolute internally, even when users pass relative timeouts.

Rules:

- `timeout` is converted to an absolute deadline at scheduling time.
- A child task inherits the earlier of:
  - the parent group deadline
  - its own explicit deadline or timeout
- If a deadline expires before a queued task starts, the task is skipped.
- If a deadline expires while a task is running, the context is cancelled with `deadlineExceeded`.

This avoids drift when task trees are nested several levels deep.

## Failure Policy

Two policies are enough for the first version:

- `cancelOnError`: a child failure cancels sibling work in the same group and bubbles to the parent.
- `supervisor`: a child failure is recorded but does not cancel siblings automatically.

This should be configured per group, not per engine.

## Reactive State Model

`LevitReactiveTasksMixin` should keep the existing flat task map, but add group-aware metadata.

### TaskDetails additions

```dart
class TaskDetails {
  final LxStatus<dynamic> status;
  final double weight;
  final double progress;
  final bool started;

  final String groupId;
  final String path;
  final DateTime? deadline;
  final LevitTaskCancellationReason? cancellationReason;
}
```

### New group state

```dart
class TaskGroupDetails {
  final String id;
  final String path;
  final String? parentId;
  final DateTime? deadline;
  final LevitTaskFailurePolicy failurePolicy;

  final int queuedCount;
  final int runningCount;
  final int completedCount;
  final int failedCount;
  final int cancelledCount;

  final LxStatus<void> status;
}
```

This allows UI and tooling to answer questions the current model cannot:

- Which workflow is busy?
- Which subtree failed?
- Which task was cancelled because a parent deadline expired?

## Instrumentation Changes

`LevitTaskEvent` should gain tree metadata:

```dart
class LevitTaskEvent {
  final String taskId;
  final String path;
  final String groupId;
  final String? parentGroupId;
  final DateTime? deadline;
  final LevitTaskCancellationReason? cancellationReason;
}
```

`TaskSkipReason` should also be extended so skips caused by deadline expiry or parent cancellation are distinguishable from cache hits.

This is important for `levit_monitor` and future devtools work.

## Engine Strategy

This proposal does not require replacing `LevitTaskEngine`.

The current engine can stay the low-level executor that owns:

- The active task map.
- The priority queues.
- Retry scheduling.
- Progress callbacks.

The structured-concurrency layer can sit above it:

- `LevitTaskGroup` manages the task tree and cancellation tokens.
- Groups submit leaf tasks into `LevitTaskEngine.schedule(...)`.
- Engine execution callbacks update both leaf task state and group aggregates.

That reduces migration risk and preserves the existing queue implementation.

## Isolate Behavior

`runInIsolate` does not map cleanly onto a context-bearing task closure.

For the first structured version, the safest rule is:

- Keep `tasksEngine.schedule(..., runInIsolate: true)` as-is.
- Do not add `group.run(..., runInIsolate: true)` until there is a dedicated API for sendable inputs and outputs.

If isolate support is added later, it should probably be a separate method with stricter typing, not a boolean flag on the context-aware API.

## Migration Path

### Phase 1

- Keep `LevitTaskEngine.schedule(...)`.
- Keep `LevitReactiveTasksMixin.runTask(...)`.
- Add `taskRoot`.
- Add `taskRoot.run(...)` and `taskRoot.group(...)`.

### Phase 2

- Extend `TaskDetails` with group/path/deadline metadata.
- Add `taskGroups`.
- Extend task events with tree metadata.

### Phase 3

- Add group failure policy.
- Add inherited deadlines.
- Add controller-close cancellation reason.

### Phase 4

- Add tooling and monitor integration once the event model stabilizes.

This sequence keeps existing code valid while enabling gradual adoption.

## Compatibility Rules

To avoid breaking current code:

- `runTask(...)` should continue to return `Future<T?>`.
- `cancelTask(id)` and `cancelAllTasks()` should continue to work.
- Internally, existing flat task ids can map to leaf tasks under the root group.

This means old code can coexist with group-based workflows during migration.

## Recommended First Implementation

The first implementation should stay small:

1. Add `LevitTaskGroup` and `LevitTaskContext`.
2. Create one controller-owned root group.
3. Support cancellation trees.
4. Support inherited deadlines.
5. Extend events and reactive state with group metadata.

What should wait:

- Group-local concurrency caps.
- Isolate-aware structured tasks.
- Persistent serialization of entire task trees.
- Rich policy matrices beyond `cancelOnError` and `supervisor`.

## Summary

Structured concurrency is a strong fit for Levit because it extends an existing architectural rule instead of adding another unrelated convenience API:

- Scopes own controllers.
- Controllers own reactive resources.
- Controllers should also own task trees.

That keeps async work inside the same ownership model as the rest of the framework.
