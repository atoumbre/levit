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
  levit_dart: ^0.1.0-beta.1
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
| `drop` | Complete with `LevitTaskDroppedException` without running the submission. |
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

Task groups, inherited deadlines and cancellation trees are available in 0.1.0.
See [structured workflows below](#structured-workflows-in-010) and the
[architecture summary](../../../proposals/structured_concurrency.md).

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

## Awaited task shutdown

`await tasksEngine.dispose()` closes admission, signals cancellation, and waits for running execution bodies and cleanup. Both task mixins drain in `onBeforeClose`, before other controller-owned resources are released. `cancelAll()` only signals cancellation.

There is no implicit timeout or hard cancellation. Uncooperative work delays disposal. An application timeout does not complete the underlying cleanup. Tasks must not await disposal of their own engine or controller; release task-local resources in their own `finally` blocks. Put dependent resource cleanup under `own` so the preparation hook runs first.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md) before upgrading.

## 0.1.0 loop completion

Await `stopService`, `stopAllServices`, and `LevitLoopEngine.dispose`: an active
iteration, including its finally blocks, finishes before stop completes.
Isolate loops acknowledge graceful completion before their ports close.
Await `stopService(id)` before registering a replacement for the same ID.
Bulk lifecycle resume preserves services explicitly paused with `pauseService`.


## Structured workflows in 0.1.0

Both task mixins expose a controller-owned `taskGroup` whose policy is
`supervisor`. Start workflows with `taskGroup.runGroup((group) async { ... })`;
workflow groups default to `cancelOnError`. Submit leaf work through `group.submit`
or `group.schedule`, and nest coordination with `group.runGroup`. Group bodies
consume no worker slots. A leaf task must not coordinate another group while
holding an execution slot; place coordination in the workflow body.

```dart
await taskGroup.runGroup((group) async {
  final uploads = files.map((file) => group.schedule((task) async {
    task.throwIfCancelled();
    return repository.upload(file, cancelled: task.cancelled);
  })).toList();
  await Future.wait(uploads);
}, name: 'project-sync');
```

Group completion waits for the body and every descendant's finally block. A failed
upload cancels sibling uploads; unrelated supervisor-root work continues. Deadlines
are absolute `DateTime` values, include queue time, and inherit the earliest limit.
Cancelling signals cooperative work and drains it; deadlines never count as cleanup.

Value-returning methods return `Future<T>`. A successful `null` remains valid when
`T` is nullable. Cancellation, dropping and supersession throw typed exceptions;
`LevitTaskExecution.outcome` instead resolves to a success, failure, cancellation,
dropping or supersession value. Ordinary task errors belong to task results;
errors thrown while unwinding cancellation also fail awaited owner cleanup.

Task IDs conflict within their owning group. Pending submissions default to a
256-entry limit (`maxPending: null` explicitly opts out). Join and replacement of
a pending coalesced tail do not consume another entry. Eligible tasks use FIFO
within each priority; a 4:2:1 high/normal/low cycle prevents starvation during
sustained contention. Controller task mixins default to 8 execution slots; override
`maxConcurrentTasks` for the workload.

Retries use `LevitRetryPolicy` with a required `shouldRetry(error, stack)` classifier,
`maxRetries`, `initialDelay`, `maxDelay`, and bounded jitter. Cancellation/deadline
errors are never retried. `tasksEngine.taskTree` exposes immutable reactive group
metadata, pending/running counts and cancellation reasons. Event summaries and
`TaskDetails` retain group/deadline/reason metadata without task dependency values.
Dedicated `submitIsolate`/`scheduleIsolate` entrypoints accept `group:` and propagate
its cancellation reason through the isolate channel, awaiting actual isolate exit.

## Queries in 0.1.0

Own a `LevitAsyncMap<K, T>` at the feature boundary:

```dart
final results = own(LevitAsyncMap<String, List<Item>>(
  (search, task) => repository.search(search, cancelled: task.cancelled),
  engine: tasksEngine,
));
final view = results.entry('flutter'); // Stable until eviction.
final status = results['flutter'];     // First read starts a missing load.
final items = await results.fetch('flutter'); // Reuse fresh data or join work.
await results.refresh('flutter');      // Waits for the load result.
```

Reads do not revalidate existing entries. Waiting and failure statuses retain
previous data; failures also reach the caller awaiting the operation. `peek`
never starts a load. Invalidation refreshes observed entries and evicts inactive
ones; explicit eviction rejects observed entries. An evicted view stays closed.
Freshness and inactive grace each default to 30 seconds, with at most 128 inactive
entries. Observers and pending fetch/refresh calls pin entries against automatic
eviction. A supplied engine is borrowed; otherwise the map owns an eight-slot
engine. Await closure to drain outstanding work.

For ordered entities use an `LxList<ID>` for order and a `LevitAsyncMap<ID, T>`
for data. Read `entities.entry(order[index])` so reordering IDs does not move
the entities' requests, retained values or freshness.

See `examples/async_catalog` for search keys with pagination, retained-data UI,
application-owned optimistic overlays, rollback, and awaited repository cleanup.

## Advanced: elapsed-time countdowns (0.1.0)

`LevitTimeMixin.startCountdown` owns the countdown until controller teardown.

```dart
final countdown = startCountdown(
  duration: const Duration(seconds: 5),
  interval: const Duration(milliseconds: 100),
  onTick: (remaining) => print(remaining),
  onFinish: () => print('Finished'),
);
countdown.pause();  // Freeze the exact remaining time, including partial ticks.
countdown.resume(); // Continue, excluding all time spent paused.
countdown.stop();   // Reset to five seconds without finishing.
countdown.start();  // Begin a fresh five-second run.
```

Remaining time comes from a monotonic Stopwatch, rather than counting callbacks.
If a callback arrives late, the next update catches up; missed ticks are not replayed.
The final update is scheduled at the deadline, even when the duration is not a
multiple of the interval. It publishes zero and calls `onFinish` once. Pause updates
remaining time immediately without an extra tick, unless the deadline already
passed, in which case it completes. App lifecycle transitions do not automatically
pause it: explicitly call pause/resume when that is the desired behavior.

Durations must be non-negative and intervals positive. A zero-duration run finishes
asynchronously on the next timer turn. `start` always resets; `resume` only resumes
a paused run. Stopping/restarting/disposing during a notification prevents obsolete
callbacks from continuing. Callbacks are synchronous; use the task engine for async
work. The published `remaining` value is output, not a deadline-setting API.

Standalone `LxCountdown` implements `LevitDisposable`: use `own(countdown)` or await
`countdown.dispose()` yourself. Disposal cancels timing immediately and drains
reactive cleanup; repeats share the completion. New controls after disposal throw.
The mixin waits for tracked task cleanup, cancels all countdowns, then awaits their
cleanup and reports failures after all attempts. It rejects countdown creation once
the controller starts closing. For deterministic tests, pass a controlled `Stopwatch`
to the standalone constructor; the countdown exclusively controls that stopwatch.

Persistence codecs/storage and persistent task caches belong to the independent
[ecosystem roadmap](../../../reports/ecosystem_roadmap.md), outside runtime dependencies.

Task queue accounting maintains the number of pending leaf entries without
rescanning the execution map on submission. Joins and coalesced replacements
share their entry; cancellation and shutdown update counts immediately. Task
event objects are created when an engine, execution or global observer is
attached. Awaited runners and their execution-zone disposal guards remain active
regardless of instrumentation.

Task outcomes are constructed when first observed. A handle keeps its result and
error available to late listeners without producing an uncaught error merely
because `outcome` was read after completion. Uncached callbacks still begin after
admission; cancellation, deadlines and disposal guards remain in their execution
context. Cleanup tracks the runner itself through all asynchronous continuations.
Generated task/execution IDs remain unique within the process; their textual
format is diagnostic and should not be parsed for timestamps.
