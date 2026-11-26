# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart` adds controller-owned operational utilities on top of
`levit_dart_core`:

- Structured task orchestration (`LevitTaskEngine`, `LevitTaskGroup`,
  `LevitTasksMixin`, `LevitReactiveTasksMixin`, `LevitRetryPolicy`).
- Keyed task-backed queries (`LevitAsyncMap`).
- Managed periodic/continuous loops (`LevitLoopMixin`, `LevitLoopEngine`).
- Selection and elapsed-time helpers (`LevitSelectionMixin`, `LevitTimeMixin`,
  `LevitCountdown`).

Use this package directly when you want the pure Dart utility layer. For the
recommended app-level single import, use [`levit`](https://pub.dev/packages/levit)
(pure Dart) or [`levit_flutter`](https://pub.dev/packages/levit_flutter) (Flutter).

## Getting Started

```yaml
dependencies:
  levit_dart: ^0.1.0
```

```dart
import 'package:levit_dart/levit_dart.dart';

class SyncController extends LevitController with LevitReactiveTasksMixin {
  Future<void> sync() async {
    await runTask(
      (task) async {
        task.reportProgress(0.25);
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
| `LevitTasksMixin` | You need scheduling, retries, caching, or cancellation without UI-facing reactive task state. | `taskEngine.schedule(...)`, `taskGroup.runGroup(...)` |
| `LevitReactiveTasksMixin` | You want reactive task details, busy state, and progress observable by UI or runtime code. | `runTask(...)`, `tasks`, `isBusy`, `totalProgress`, `hasBlockingTasks` |

Both mixins own one `LevitTaskEngine` and drain active runners during
`onBeforeClose` before other owned resources are released.

## Named Work & Conflict Policies

Use a stable logical `id` whenever callers can overlap within the same group,
either via `conflictPolicy:` or the shorthand helpers on `LevitTasksMixin` and
`LevitReactiveTasksMixin`:

| Policy | Shorthand helper | Behavior |
| :-- | :-- | :-- |
| `reject` | `runTask(..., id: id)` | Default. Fail the new submission with `LevitTaskConflictException`. |
| `join` | `runJoin(id, task)` | Share the result of the latest outstanding execution. |
| `drop` | `runDrop(id, task)` | Complete with `LevitTaskDroppedException` without running the submission. |
| `restart` | `runLatest(id, task)` | Cooperatively cancel outstanding work and admit the replacement. |
| `enqueue` | `runQueued(id, task)` | Preserve every submission in FIFO order for that logical ID. |
| `coalesceLatest` | `runCoalesceLatest(id, task)` | Keep one trailing execution and replace its work with the latest submission. |

```dart
final execution = controller.taskEngine.submit(
  (context) async {
    final result = await repository.sync(
      onProgress: context.reportProgress,
    );
    context.throwIfCancelled();
    return result;
  },
  id: 'sync-drain',
  conflictPolicy: LevitTaskConflictPolicy.join,
  metadata: const LevitTaskMetadata(
    debugName: 'sync drain',
    category: 'sync',
  ),
);

execution.cancel();
await execution.result;
```

Use `scheduleIsolate`, `submitIsolate`, or `runIsolateTask` with a top-level or
static entrypoint for isolate work (pass `group:` to bridge group cancellation
and await actual isolate exit).

## Structured Workflows

Both task mixins expose a supervisor-root `taskGroup`. Start coordinated
workflows with `taskGroup.runGroup((group) async { ... })`; child workflow
groups default to `cancelOnError` and await every descendant's `finally` block:

```dart
await taskGroup.runGroup((group) async {
  final uploads = files
      .map(
        (file) => group.schedule(
          (task) async {
            task.throwIfCancelled();
            return repository.upload(file, cancelled: task.cancelled);
          },
        ),
      )
      .toList();
  await Future.wait(uploads);
}, name: 'project-sync');
```

Key scheduling and lifecycle guarantees:

- **Slots & backpressure:** Group bodies coordinate without consuming worker
  slots; only leaf tasks occupy slots (controller mixins default to `8` slots;
  pending submissions default to `maxPending: 256` with 4:2:1 high/normal/low
  fairness).
- **Deadlines & retries:** Deadlines are absolute `DateTime` values that include
  queue time and inherit the earliest limit. `LevitRetryPolicy` requires a
  `shouldRetry(error, stack)` classifier with bounded exponential backoff +
  jitter; cancellation and deadline errors are never retried.
- **Outcomes & shutdown:** `LevitTaskExecution.outcome` distinguishes success
  (including nullable `null`), failure, cancellation, dropping, and supersession.
  `await taskEngine.dispose()` closes admission, signals cancellation, and waits
  for running bodies and `finally` cleanup—there is no implicit hard timeout.
- **Aggregate tracking & telemetry:** Attach `LevitTaskTracker` under a
  long-lived owner for app-wide busy/blocking state, observe live groups via
  `taskEngine.taskTree`, or subscribe to `LevitTaskMiddleware` in your
  composition layer to bridge events to `LevitMonitor.emitCustomEvent` without
  coupling domain code to `levit_monitor`.

## Queries

Own a `LevitAsyncMap<K, T>` at the feature boundary for keyed, task-backed
loading with freshness and bounded retention:

```dart
final results = own(
  LevitAsyncMap<String, List<Item>>(
    (search, task) => repository.search(search, cancelled: task.cancelled),
    engine: taskEngine,
  ),
);
final view = results.entry('flutter');        // Stable observation handle.
final status = results['flutter'];            // First read starts a load.
final items = await results.fetch('flutter'); // Reuse fresh data or join.
await results.refresh('flutter');             // Force reload and await result.
```

- Waiting and error statuses retain previous data (`status.hasLastValue`);
  `peek` reads without starting a load.
- Freshness and inactive grace each default to 30 seconds (up to 128 inactive
  entries); active observers and in-flight `fetch`/`refresh` calls pin entries
  against eviction.
- For ordered entities, combine an `LxList<ID>` for order with a
  `LevitAsyncMap<ID, T>` for data and observe `entities.entry(order[index])`.
- See [examples/async_catalog](https://github.com/softilab/levit/tree/main/examples/async_catalog)
  for pagination, retained-data UI, and optimistic updates with rollback.

## Loop Completion

Use `LevitLoopMixin` / `LevitLoopEngine` for managed periodic or continuous
workloads:

- Always await `stopService`, `stopAllServices`, and `LevitLoopEngine.dispose`:
  active iterations (including `finally` blocks) and isolate ports finish
  gracefully before stop completes.
- Await `stopService(id)` before registering a replacement for the same ID.
- Bulk resume preserves services explicitly paused with `pauseService`.

## Elapsed-Time Countdowns

`LevitTimeMixin.startCountdown` creates a controller-owned countdown backed by
a monotonic `Stopwatch`:

```dart
final countdown = startCountdown(
  duration: const Duration(seconds: 5),
  interval: const Duration(milliseconds: 100),
  onTick: (remaining) => print(remaining),
  onFinish: () => print('Finished'),
);
countdown.pause();  // Freeze exact remaining time, including partial ticks.
countdown.resume(); // Continue, excluding paused duration.
countdown.stop();   // Reset to full duration without calling onFinish.
countdown.start();  // Start a fresh run.
```

- Delayed ticks catch up rather than replaying missed callbacks, and the
  deadline tick always publishes `Duration.zero` and calls `onFinish` once.
- Callbacks are synchronous; use the task engine for async work. Pass a custom
  `Stopwatch` to standalone `LevitCountdown` for deterministic tests, and own
  or await `dispose()` on standalone instances.

## Design Principles

- **Controller-first ownership:** tasks, queries, loops, and timers drain cleanly on controller close.
- **Explicit concurrency semantics:** conflict policies, deadlines, retries, and cancellation are opt-in and visible.
- **Pure Dart portability:** zero Flutter dependency.
