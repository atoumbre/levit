## 0.1.0-beta.1

- **Breaking:** Requires Dart 3.7+.
- Add structured task workflows with `LevitTaskGroup` (`taskGroup.runGroup`), inherited absolute deadlines, `LevitRetryPolicy`, `taskEngine.taskTree`, conflict-policy shorthand helpers (`runLatest`, `runDrop`, `runQueued`, `runJoin`, `runCoalesceLatest`) on `LevitTasksMixin` and `LevitReactiveTasksMixin`, and a default `maxPending` cap of `256`.
- Add `LevitAsyncMap` for observed keyed loads, freshness-aware fetches, and bounded inactive eviction with observer/in-flight pinning.
- Measure `LevitCountdown` / `LevitTimeMixin.startCountdown` from monotonic elapsed time, preserve partial pauses, finish at the exact deadline, and await countdown cleanup.
- Await graceful completion of active iterations and isolate shutdown in `LevitLoopEngine.stopService`, `stopAllServices`, and `dispose`.
- Updated internal package constraints to `^0.1.0-beta.1`.

## 0.0.12

- Preserve countdown and loop resources while tasks drain, regardless of mixin order.
- **Breaking:** task engine disposal awaits execution runners and cleanup after cancellation.
- Task mixins drain during `onBeforeClose`, keeping owned resources alive until work finishes.
- Updated internal runtime constraints to `^0.0.12`.

## 0.0.11

- **Breaking:** task callbacks now receive `LevitTaskContext`; isolate work uses
  the dedicated `scheduleIsolate`, `submitIsolate`, and `runIsolateTask` APIs.
- Expand `LevitTaskEngine`, `LevitTasksMixin`, and
  `LevitReactiveTasksMixin` instead of adding a parallel action abstraction.
- Add named logical task IDs with `reject` (default), `join`, `drop`, `restart`,
  `enqueue`, and `coalesceLatest` conflict policies.
- Add cooperative cancellation, validated progress, execution handles, isolate
  progress/cancellation bridging, retries, and per-execution metadata.
- Add dependency-neutral structured task events, global
  `LevitTaskMiddleware`, and opt-in `LevitTaskTracker`.
- Add reactive category/blocking selectors and execution-ID protection against
  stale completion publication.
- Make task engines controller-owned and await their lifecycle cleanup.
- Updated internal package constraints to `^0.0.11`.

## 0.0.10
- `LevitTasksMixin.tasksEngine` lazy-inits before `onInit` and throws a clear error after `onClose`.
- `LevitReactiveTasksMixin` lazily initializes `isBusy` and `totalProgress`; clear error after close.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.10`.

## 0.0.9
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.9`.


## 0.0.8
- Refactored task-engine support code into smaller internal modules without changing the public API.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.8`.

## 0.0.7
- Bumped version to 0.0.7

## 0.0.6

### Breaking Changes
- **Renamed Mixins**:
    - `LevitExecutionLoopMixin` -> `LevitLoopExecutionMixin`
- **FEAT**: Added `startIsolateLoop` to `LevitLoopExecutionMixin` for running background tasks in separate isolates.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Task management mixins with priority queuing
- Retry logic with exponential backoff
- Isolate task execution support

## 0.0.4
- Initial release
