# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart` adds higher-level pure Dart utilities on top of `levit_dart_core`.

Use this package when you want the utility layer directly.
If you want the recommended app-level single import for pure Dart, use `levit`.

This package is responsible for:

- Controller task execution helpers and lifecycle-aware task orchestration.
- Loop execution helpers for periodic/continuous workloads.
- Focused utility mixins (selection/time helpers) for controller state.

This package does not include:

- Flutter widget bindings (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

The package keeps controller ownership explicit while reducing boilerplate for common operational patterns:

- Queueing and retrying tasks with structured lifecycle events.
- Choosing between engine-only task orchestration and reactive task state.
- Running managed loops tied to controller disposal.

## Getting Started

```yaml
dependencies:
  levit_dart: ^latest
```

```dart
import 'package:levit_dart/levit_dart.dart';

class SyncController extends LevitController with LevitReactiveTasksMixin {
  Future<void> sync() async {
    await runTask(
      (task) async {
        task.reportProgress(.25);
        // perform sync work
        task.throwIfCancelled();
      },
      id: 'sync',
      metadata: const LevitTaskMetadata(
        category: 'sync',
        blocksUserInteraction: true,
      ),
    );
  }
}
```

## Choosing a Task Mixin

| Mixin | Use when | Primary API |
| :-- | :-- | :-- |
| `LevitTasksMixin` | You need scheduling, retries, caching, or cancellation without UI-facing reactive task state. | `tasksEngine.schedule(...)` |
| `LevitReactiveTasksMixin` | You want reactive task details, busy state, and progress that can be observed by other runtime code or UI. | `runTask(...)`, `tasks`, `isBusy`, `totalProgress` |

Both mixins own one `LevitTaskEngine`; there is no separate action lifecycle or
registry to keep synchronized.

## Named Work and Conflict Policies

Use a stable logical `id` whenever callers can overlap:

| Policy | Behavior |
| :-- | :-- |
| `reject` | Default. Fail the new submission with `TaskConflictException`. |
| `join` | Share the result of the latest outstanding execution. |
| `drop` | Ignore the new submission and return `null`. |
| `restart` | Cooperatively cancel outstanding work and admit the replacement. |
| `enqueue` | Preserve every submission in FIFO order for that logical ID. |
| `coalesceLatest` | Keep one trailing execution and replace its work with the latest submission. |

Use `LevitTaskContext` for cancellation and progress. Cancellation is
cooperative: await `context.cancelled` or call `throwIfCancelled()` at safe
points.

```dart
final execution = controller.tasksEngine.submit(
  (context) async {
    final result = await repository.sync(
      onProgress: context.reportProgress,
    );
    context.throwIfCancelled();
    return result;
  },
  id: 'sync-drain',
  conflictPolicy: TaskConflictPolicy.join,
  metadata: const LevitTaskMetadata(
    debugName: 'sync drain',
    category: 'sync',
  ),
);

execution.cancel();
await execution.result;
```

Use `scheduleIsolate`, `submitIsolate`, or `runIsolateTask` with a top-level or
static entrypoint for isolate work. These APIs bridge progress and cooperative
cancellation explicitly; ordinary context-bearing callbacks are not sent to an
isolate.

## Aggregate Task State

`LevitReactiveTasksMixin` exposes per-controller state plus category and
blocking selectors: `taskStatus`, `taskProgress`, `isBusyWhere`,
`progressWhere`, and `hasBlockingTasks`.

For one application-level view, explicitly attach a `LevitTaskTracker` and
place it under a long-lived owner:

```dart
class RuntimeController extends LevitController {
  late final tracker = own(
    LevitTaskTracker()..attach(token: #root_task_tracker),
  );

  LxComputed<bool> get showBlockingUi => tracker.hasBlockingTasks;
}
```

The tracker consumes structured middleware events and does not require
controllers to publish into a second task model.

For the next-step design direction for task groups, inherited deadlines, and cancellation trees, see [`proposals/structured_concurrency.md`](../../../proposals/structured_concurrency.md).

## Optional monitor bridge

`levit_dart` exposes dependency-neutral `LevitTaskEvent`s through
`LevitTaskMiddleware`. `levit_monitor` exposes generic custom events and does
not depend on this package. An application that imports both can bridge them:

```dart
class TaskMonitorBridge extends LevitTaskMiddleware {
  @override
  void onTaskEvent(LevitTaskEvent event) {
    LevitMonitor.emitCustomEvent(
      namespace: 'levit.task',
      name: event.type.name,
      sensitive: event.metadata.sensitive,
      attributes: {
        'executionId': event.executionId,
        'ownerPath': event.ownerPath,
        'debugName': event.metadata.debugName,
        'category': event.metadata.category,
        'priority': event.priority.name,
        'attempt': event.attempt,
        'phase': event.phase.name,
        'outcome': event.outcome?.name,
        'queueUs': event.queueDuration?.inMicroseconds,
        'runUs': event.runDuration?.inMicroseconds,
      },
      error: event.error,
      stackTrace: event.stackTrace,
    );
  }
}

final bridge = LevitTaskMiddleware.add(TaskMonitorBridge());

// During application teardown:
LevitTaskMiddleware.remove(bridge);
```

Keep this adapter in the application composition layer. Do not add
`levit_monitor` imports to domain code.

## Design Principles

- Controller-first ownership and cleanup.
- Explicit concurrency semantics.
- Reusable utilities without hiding underlying lifecycle mechanics.
