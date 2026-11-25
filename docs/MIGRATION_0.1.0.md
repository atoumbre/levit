# Migration to Levit 0.1.0

This guide covers the coordinated breaking release, including the unpublished
0.0.12 work. No compatibility aliases are provided. Requires Dart 3.12+ and Flutter 3.44+.

## Ownership and lookup changes

- Replace `autoDispose(resource)` with `own(resource)`. Unknown resource types
  require `own(resource, dispose: (value) => value.dispose())`; method-name guessing
  is removed. Supported reactive resources, scopes, Levit disposables, stream
  subscriptions, timers, sinks and cleanup functions have explicit adapters.
- Await reactive `close()`, owner/scope disposal and loop `stop()`. Cancellation
  requests and deadlines do not complete cleanup. `disposed` stays pending until
  terminal cleanup; await the cleanup operation itself to receive failures.
- Deletion/disposal middleware errors no longer interrupt subsequent observers
  or owned resource cleanup. Awaited `delete`, `reset` and scope disposal report
  them together with resource failures through `LevitDisposalException`.
  A failed alias-deletion observer does not close the canonical instance.
- Workers can use `LxWorker.withContext` for cooperative cancellation. `latest`
  requests cancellation of superseded work and still drains its finally blocks.
- `LevitRef.onDispose` accepts asynchronous callbacks. Return their futures.
- Start external setup with `scope.runInitialization(() async { ... })` so it is
  admitted before user code runs and cannot await disposal of its own scope.
  Async DI builders and captured controller/store initializers have the same
  self-disposal guard. Request cancellation there; await cleanup externally.
  `trackInitialization(future)` adopts work already started and cannot change its
  original execution context.
- Manually created child scopes are parent-owned by default. Use
  `ownedByParent: false` for an explicitly borrowed child and close it separately.
- Factory registration no longer implies permanence. Use `permanent: true` only
  when it should survive a regular reset. Await `scope.releaseFactoryInstance`
  when an owned factory instance is no longer needed.
  Early release follows cancellation → drain → close and is included in scope
  cleanup. Delete/reset/release calls from the work they would drain are rejected
  before changing registrations.
  An early-release failure is also reported by registration/scope cleanup;
  releasing resources retain their self-disposal guard until completion.
- Replace duplicate loop IDs by awaiting `stopService(id)` before registration.
- Flutter scope replacement drains the previous generation, coalesces updates,
  and exposes loading/failure/retry through `LevitScopeLifecycleController`.
  Keep the lifecycle controller stable for a mounted widget. Await `close()`
  to observe cleanup failures; `closed` only signals completion. `settled`
  observes replacement completion; inspect `error` before using the scope.
- Store keys are definition identity plus variant. Install typed `overrideWith`
  recipes with `scope.applyOverrides` before local resolution. Use `findStore`
  or `findAsyncStore` on `context.levit`/`LevitRef`; dynamic `key:` lookup and
  redundant `findStoreAsync`/`*.findAsync` wrappers are removed. `localOnly: true`
  explicitly creates local state.
- Optional DI lookup returns null only for an absent registration. Construction
  and type errors now propagate.
- Builders/selectors accept `LxReadable<T>`. `LxState.asReadable` exposes observation
  without setters, refresh or disposal. Scope descriptions omit values/raw tags.

## Direct removals

| Removed API | Change |
| --- | --- |
| `.toBuilder` | Construct inside the registration builder. |
| `.levitPut`, `.levitLazyPut`, `.levitLazyPutAsync` | Use explicit scope or Levit registration. |
| `initialized` | Read `isInitialized`. |
| `computedValue` | Read `requireValue`. |
| `runGuardedAsync(cancelOnClose:)` | Use `discardResultOnClose:`; this helper discards results, without cancelling the underlying operation. |
| `LevitReactiveHistoryMiddleware` | Application-owned commands with explicit inverses; see Nexus. |
| `LWidgetMonitor` | Local mount/unmount StatefulWidget recipe. |

Nexus commands synchronize inverse creation, position and color operations. Remote
document changes clear local history; presence does not. Removed nodes are sent as
idempotent `node_delete` messages.

## Structured tasks

- Replace `retries`, `retryDelay`, and `useExponentialBackoff` arguments with an
  explicit `LevitRetryPolicy`. Supply an application error classifier and capped
  delays; cancellation/deadline exceptions bypass retry.
- Task result types are `Future<T>`. Handle cancellation/dropping/supersession as
  typed exceptions, or observe `execution.outcome`. Do not interpret a nullable
  successful result as cancellation.
- Use `controller.taskGroup.runGroup` for workflows and child groups. The controller
  root supervises unrelated work; workflow groups cancel siblings on error by
  default. Coordinate in group bodies and submit leaf work inside them.
- Logical IDs conflict within a group. Default pending capacity is 256; use
  `LevitTaskEngine(maxPending: null, ...)` only for an explicit unbounded queue.
  Controller mixins default to 8 concurrent leaf tasks, configurable through
  `maxConcurrentTasks`. Weighted priorities preserve low-priority progress.
- Group deadlines include queue time; cancellation reasons flow into isolates and
  diagnostics. Cleanup waits for all descendants and isolate exit, not a deadline.

## Families, queries and status builders

- Replace plain value families with a borrowing `map.entry(key)` or
  `list.entry(index)`. A position tracks the index, not the item.
- Replace `LxFamilyHandle<T,R>` for one custom producer with an owned
  `LxResource<T,R>(() => createProducer())`. Replace `handle.resource` with
  `resource.producer`; `await resource.refresh()` drains the old producer and
  validates its replacement. Ordinary maps do not close their contents.
- Replace `LevitQueryFamily<K,T>` with `LevitAsyncMap<K,T>`. For example,
  `LStatusBuilder(queries(key), ...)` becomes
  `LStatusBuilder(queries.entry(key), ...)`. For an immediate status use
  `queries[key]`. Replace `await family.refresh(key)` with
  `await queries.refresh(key)` to wait for the **load result**, or
  `final data = await queries.fetch(key)` to reuse fresh data. Old evicted
  views stay closed. The query producer is private.
- Use `status.hasLastValue` to distinguish no prior data from a successful `null`.
  Custom transitions should use `.fromPrevious` or `.retained` constructors.
- `LStatusBuilder.onWaiting`, `onIdle` and `onError` now receive one full status.
  Replace `onWaiting: () => ...` with `(status) => ...`, and
  `onError: (error, stack) => ...` with `(status) => ...` using `status.error` and
  `status.stackTrace`. Worker status callbacks retain their own signatures.

## Earlier unpublished 0.0.12 changes

The following earlier changes are cumulative requirements for this release.

Upgrade all runtime packages together to `^0.1.0`. The following contracts
originated in the unpublished 0.0.12 work and remain part of 0.1.0.

## Reactive calls only read

```dart
final count = 0.lx;
print(count());        // Read: unchanged syntax, now safe for nullable values.
count.value = 1;       // Replaces count(1).
count.value++;         // Replaces count(count() + 1).
```

For nullable state, use `value.value = null`. An omitted call argument can no
longer clear a value. Computed values and ordinary function calls are unchanged.

## Construct dependencies inside builders

Removed: instance `.levitPut()` / `.levitLazyPut()` and existing-future
`.levitLazyPutAsync()`. Builder registration extensions are also removed; use the explicit APIs below.

```dart
Levit.put(() => Repository());
Levit.lazyPut(() => Repository());
Levit.lazyPutAsync(() async => await createRepository());
```

Move construction itself into the builder. Wrapping an already-created owner in
`() => existing` does not capture its earlier reactive allocations. Deliberately
external resources require explicit ownership and cleanup.

## Consuming views do not register dependencies

Removed: `LView.put` and `LAsyncView.put`.

- For a view-owned dependency, use `LScopedView.put` or `LAsyncScopedView.put`.
- For a shared dependency, register it in the existing owning scope’s
  `configure` callback and consume it through `LView` or `LAsyncView`.

Choose the migration according to the intended lifetime. Changing a shared
registration to a scoped view intentionally shortens its lifetime.

## Factory results belong to the registering scope

Disposable factory results now close with their registration. Resolving through
a child scope does not transfer ownership to that child. Cleanup preserves
registration order and closes each factory’s results in reverse creation order.

Await deletion before registering a replacement. Deletion and disposal wait for
pending async construction; late results are closed and rejected to their
resolvers. Handle those resolution errors when creation can overlap teardown.
Factory registrations are no longer implicitly permanent; request permanence explicitly.

Remove redundant manual disposal of factory results when their registration
already owns them. Use a suitably short-lived registering scope when retaining
many transient resources until app shutdown would be inappropriate.

## Async batching is independent across execution contexts

`batchAsync` remains available. Outside writes notify immediately while a batch
awaits work. Concurrent batches flush independently; nested batches merge into
the enclosing open batch. Errors flush collected notifications before propagating.

Values remain shared. An outside write to a reactive also touched by a pending
batch is visible immediately, and a later batch flush observes the current value.
Neither batching API supplies transactional isolation or rollback.

Batch middleware can inspect `LevitReactiveBatch.isAsync` to decide whether the
boundary includes future completion. A synchronous batch closes when its callback
returns, even if the returned value happens to be a future.

Prefer awaiting remote work before a short synchronous commit where practical:

```dart
final result = await load();
Levit.batch(() {
  data.value = result;
  loading.value = false;
});
```

## Await task shutdown

`LevitTaskEngine.dispose()` now returns `Future<void>`. It rejects new work,
cancels queued/running work, and waits for execution runners and cleanup. Both
task mixins drain before releasing controller-owned resources.

```dart
await engine.dispose();
await scope.dispose();
```

`cancelAll()` only signals cancellation. Work must cooperate by observing its
task context, and release task-local resources in `finally`. A task that ignores
cancellation can delay disposal indefinitely; a timeout on the caller’s wait
does not mark cleanup complete. Tasks must not await their own owner’s disposal.

The new protected `onBeforeClose()` hook runs after closing starts and before
owned resource disposal. Always delegate to `super`, awaiting asynchronous work.
Keep resource cleanup under `own` to preserve this ordering. Normal
`onClose` overrides must still delegate to `super.onClose()`.

## Store inheritance is explicit

Stores remain initialization recipes, not reactive computations. Return a
reactive object when consumers need changing state:

```dart
final counterStore = LevitStore((ref) => ref.own(0.lx));
final inherited = counterStore.findIn(scope);
final local = counterStore.findIn(scope, localOnly: true);
```

Default lookups reuse ancestor instances. `localOnly: true` creates or reuses
only the current scope’s instance. It is available on synchronous/asynchronous
store lookups, store-specific `LevitRef` lookups, and `.store` view factories.
Creating a local instance also makes subsequent default lookups resolve locally.

## View updates use scope and arguments

`LAsyncView` no longer refetches because a resolver closure changed identity.
Both consuming view variants resolve initially, when their scope changes, or
when explicit `args` change. Pass `args: [userId]` when a captured input changes.
When a store recipe or `localOnly` option changes dynamically, include it in
`args` too. Scoped views still recreate their owned scope when ownership arguments change.
The `args` name remains supported; no `deps` parameter is introduced.

## Bootstrap ownership explicitly

```dart
void main() {
  Levit.enableAutoLinking();
  runApp(const MyApp());
}
```

Monitoring no longer enables auto-linking. Apply the same explicit configuration
in Dart entrypoints when relying on captured ownership. Set monitor filters with
`LevitMonitor.setFilter`; `attach` has no `filter` parameter.

`levit_lints` is publishable at 0.1.0. Use its native root-level plugin
configuration; until publication, select the checkout path. See the
[lint README](../packages/tools/levit_lints/README.md) for configuration and rule limits.

## Validation before upgrading an application

Run analysis to find removed APIs. Exercise route exit during initialization and
task execution, local versus inherited store state, and changing view arguments.
In widget tests, unmount the tree and await the captured scope or controller’s
disposal before asserting resource cleanup.

## M6: monitoring and the local inspector

Await `LevitMonitor.attach(...)`, `flush()` and `detach()`, including in `main` and
teardown. Replacement waits for old delivery/cleanup; cleanup errors are observable
as `LevitMonitorException` after all sinks have been attempted. Attach monitoring
before constructing scopes/state so their ownership can be inspected.

History and worker statistics default off. Opt in with `historyCapacity: 1000`
and `enableWorkerStatistics: true` for inspector sessions; add `includeStackTrace:
true` to inspect write origins. Bounded queues expose drops, and reconnect snapshots
restore current state without claiming an uninterrupted timeline.

Transports now receive immutable, redacted `LevitFrozenMonitorEvent` data. Inspect
`event.toJson()['type']` or `event.envelope` after narrowing to `LevitFrozenMonitorEvent`,
rather than downcasting captured events to runtime event classes. Extend
`LevitTransport` and preserve returned futures from buffered send/flush/close.
Filters still run on the original typed event before it is frozen.

Move `LevitFileTransport` imports to `package:levit_monitor/levit_monitor_io.dart`.
The default monitor import and `levit_monitor_protocol.dart` now compile for web.
`LevitMonitor` log levels now use `LevitLogLevel` consistently instead of `package:logger`'s `Level`.
Inspector/DevTools shadow models (`LevitStateSnapshot`, `LevitScopeModel`, `LevitMonitorMiddleware`,
and granular `Levit*Event` subtypes) are exported from `package:levit_monitor/spi.dart`.

Scope lifecycle progress uses versioned `scope_progress` records. Each record
contains complete ownership metadata in a compact wire layout; it does not rely
on earlier events. `LevitStateSnapshot.applyEnvelope` expands the record to named
fields, and reconnect snapshots retain the expanded form. Custom protocol
consumers should use that decoder or the schema in `levit_monitor/README.md`.
Use the matching 0.1.0 inspector bundle when upgrading a producer.
Scope create/dispose wire events carry scope identity without dependency-only
flags. Terminal completion is represented once by `scope_dispose`; it follows
all cleanup attempts, including failed asynchronous release.
Mark sensitive reactive values in their constructor; calling `.sensitive()` after
creation cannot retract the already-emitted initialization event.

Use the `levit_devtools` Dart CLI for the bundled local inspector (port 9200,
producer endpoint `/ws`). Its Flutter UI is a private source package. Task trees
use the optional application-owned adapter in the monitor example. Nexus app and
server both support `LEVIT_INSPECTOR_URL` as a Dart compile-time define when the
default inspector port is occupied.

## Revised M7: Flutter interoperability and countdown correctness

Persistence interfaces/codecs, migrations, storage adapters, persistent task caches
and codec-based restoration moved to the independent
[ecosystem roadmap](ecosystem_roadmap.md). They are not main 0.1.0 packages
or release gates.

`LxReadable<T>.asValueListenable()` creates an `LxValueListenable<T>` exposed through
`levit_flutter`. Own it at a controller/widget boundary and retain it outside build.
It subscribes only while it has listeners; disposal detaches without closing the
source. It preserves nullable values, collection refreshes and family-handle updates.
Use `ValueListenable<T>` as the consumer-facing type when only observation is needed.

Countdowns now use monotonic elapsed time. Delayed callbacks catch up rather than
subtracting a single interval; partial final intervals finish at the actual deadline.
`pause()` freezes the precise remainder, and `resume()` excludes paused time.
App suspension does not implicitly pause the countdown. `start()` begins a fresh
full-duration run, while `stop()` resets without finishing. `resume()` does not start
an idle/completed timer. Zero duration finishes asynchronously; negative durations
and non-positive intervals throw `ArgumentError`.

Await standalone `LevitCountdown.dispose()` or register it with `own`. The time mixin
owns countdowns it creates and awaits their cleanup after task draining. Controls
on a disposed countdown and new countdowns on a closing controller throw
`StateError`. Callback execution stays synchronous; callbacks that stop/restart/
dispose the countdown suppress remaining callbacks from the obsolete run.

## Public exposure surface & naming cleanup (0.1.0)

- **Kit facade unification:** `levit`, `levit_dart`, and `levit_flutter` hide low-level `Lx` and `Ls` facades. Use `Levit` everywhere in app code (`Levit.currentScope`, `Levit.untracked`, `Levit.isBatching`, `Levit.containsStateMiddlewareToken` were added for full parity).
- **Opt-in `tasks.dart` entrypoint:** Everyday task mixins and configs (`LevitTasksMixin`, `LevitReactiveTasksMixin`, `LevitTaskContext`, `LevitTaskPriority`, `LevitTaskConflictPolicy`, `LevitRetryPolicy`, `LevitTaskCancelledException`, `LevitTaskDetails`, `LevitTaskPhase`) remain in default kit barrels. Import `package:levit/tasks.dart`, `package:levit_dart/tasks.dart`, or `package:levit_flutter/tasks.dart` for `LevitTaskEngine`, `LevitTaskGroup`, caching, middleware, trackers, isolate tasks, and `LevitTaskResult` subtypes.
- **Cross-package SPI (`spi.dart`):** Observer/notifier/boundary/ownership/inspector plumbing moved to `package:levit_reactive/spi.dart`, `package:levit_scope/spi.dart`, `package:levit_dart_core/spi.dart`, and `package:levit_monitor/spi.dart`.
- **Clean-cut renames:**
  - Flutter widgets/context: `LScopedAsyncView` → `LAsyncScopedView`, `LevitProvider` → `LevitContext`, `dependencyFactory:` → `configure:`, `onConfigScope` → `onConfigureScope`.
  - Reactive/core: `value.lxVar(named:)` → `value.lxVar(name:)`, `LxState.asReactive` → `LxState.asReadable`, `LxNamingExtension.register` → `ownedBy`, `LxOnSet`/`LxOnBatch`/`LxOnDispose` → `LevitReactiveOnSet`/`LevitReactiveOnBatch`/`LevitReactiveOnDispose`, removed `findStoreAsync` / `*.findAsync` / `*.findAsyncIn`.
  - Dart & Flutter kits: `LxCountdown` → `LevitCountdown`, `StoppableService` → `LevitLoopService`, `LevitLoopExecutionMixin` → `LevitLoopMixin`, `LevitLoopExecutionLifecycleMixin` → `LevitLoopLifecycleMixin`, `pauseLifecycleServicesForce` → `pausePermanentServicesOnBackground`, `tasksEngine` → `taskEngine`, `TaskPriority` → `LevitTaskPriority`, `TaskConflictPolicy` → `LevitTaskConflictPolicy`, `TaskSkipReason` → `LevitTaskSkipReason`, `TaskConflictException` → `LevitTaskConflictException`, `TaskCachePolicy` → `LevitTaskCachePolicy`, `InMemoryTaskCacheProvider()` → `LevitTaskCacheProvider.inMemory()`, `TaskDetails` → `LevitTaskDetails`, `LevitCancellationKind` → `LevitTaskCancellationKind`, `LevitExecutionOutcome` (`LevitTaskCancellation`/`LevitTaskDropping`/`LevitTaskSupersession`) → `LevitTaskResult` (`LevitTaskCancelled`/`LevitTaskDropped`/`LevitTaskSuperseded`).
  - Monitor: `ConsoleTransport` / `FileTransport` / `MultiTransport` / `WebSocketTransport` → `Levit*Transport`, `MonitorEvent` + subtypes → `Levit*Event`, `StateSnapshot` + models → `Levit*` in `levit_monitor/spi.dart`, and `LevitLogLevel` replaces `package:logger`'s `Level` across `LevitMonitor`.

## M8: tooling and upgrade checklist

All runtime, lint and inspector packages use 0.1.0, Dart 3.12+ and (where used)
Flutter 3.44+. The inspector UI source remains private. Add lints through the
native `plugins` section, not legacy `analyzer.plugins`/`custom_lint`. New rules
cover awaited lifecycle delegation, global widget lookup and discarded known
cleanup futures; they do not prove general cancellation correctness.

- Replace every removed API above; no aliases or deprecation period remain.
- Resolve local packages together with `dart run melos bootstrap` while testing
  the unpublished checkout; do not mix the 0.0.12 and 0.1.0 runtime graph.
- Run fatal-info analysis and exercise initialization, refresh, cancellation and
  awaited unmount. Handle aggregate cleanup failures at the lifetime boundary.
- Follow [scopes → owners → state → widgets](ONBOARDING.md). Selection/time,
  numeric helpers, keep-alive, static dependencies and async batching remain
  supported in [advanced documentation](ADVANCED.md).
- Use the searchable catalog, save/upload task groups, session replacement and
  store-override widget tests under [examples](../examples/README.md).

This guide describes implemented contracts. Run the
[workspace checks](../CONTRIBUTING.md#running-checks) when validating a release
candidate; publication remains a separate action.
