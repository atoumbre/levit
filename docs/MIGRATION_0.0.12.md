# Migrating to Levit 0.0.12

This coordinated release changes lifecycle behavior and removes ambiguous
shortcuts. Upgrade the Levit runtime packages together to `^0.0.12`.

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
`.levitLazyPutAsync()`. Builder extensions remain available.

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

- For a view-owned dependency, use `LScopedView.put` or `LScopedAsyncView.put`.
- For a shared dependency, register it in the existing owning scope’s
  `dependencyFactory` and consume it through `LView` or `LAsyncView`.

Choose the migration according to the intended lifetime. Changing a shared
registration to a scoped view intentionally shortens its lifetime.

## Factory results belong to the registering scope

Disposable factory results now close with their registration. Resolving through
a child scope does not transfer ownership to that child. Cleanup preserves
registration order and closes each factory’s results in reverse creation order.

Await deletion before registering a replacement. Deletion and disposal wait for
pending async construction; late results are closed and rejected to their
resolvers. Handle those resolution errors when creation can overlap teardown.
Existing factory permanence during non-forced reset remains unchanged.

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
Keep resource cleanup under `own`/`autoDispose` to preserve this ordering. Normal
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

`levit_lints` remains local-only. Configure its analyzer plugin with a path to
the checkout, not a published version constraint.

## Validation before upgrading an application

Run analysis to find removed APIs. Exercise route exit during initialization and
task execution, local versus inherited store state, and changing view arguments.
In widget tests, unmount the tree and await the captured scope or controller’s
disposal before asserting resource cleanup.
