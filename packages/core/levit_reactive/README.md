# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_reactive)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_reactive` is Levit's pure Dart reactive runtime.

Building an application? Start with [`levit`](https://pub.dev/packages/levit)
(pure Dart) or [`levit_flutter`](https://pub.dev/packages/levit_flutter)
(Flutter) unless you specifically want the reactive layer standalone.

This package owns:

- Mutable and read-only reactive values (`.lx`, `LxVar`, `LxReadable<T>`).
- Derived state (`LxComputed`, `LxComputed.async`) and `LxStatus<T>`.
- Side-effect workers (`LxWorker`, `LxWorker.withContext`).
- Borrowing collection entries (`LxMap.entry`, `LxList.entry`).
- Context-local batching (`Lx.batch`, `Lx.batchAsync`) and reactive middleware.

Dependency injection lives in `levit_scope`; Flutter bindings live in
`levit_flutter_core` and `levit_flutter`.

## Getting Started

```yaml
dependencies:
  levit_reactive: ^0.1.0
```

```dart
import 'package:levit_reactive/levit_reactive.dart';

Future<void> main() async {
  final count = 0.lx;
  final doubled = LxComputed(() => count() * 2);

  final worker = LxWorker(doubled, (value) {
    print('doubled=$value');
  });

  count.value = 1;
  count.value = 2;

  await worker.close();
  await doubled.close();
  await count.close();
}
```

## Reads, Batching & Computed Dependencies

- **Read vs. write:** `count()` and `count.value` read; assign with
  `count.value = next` (including for nullable values).
- **Dynamic tracking by default:** `LxComputed` tracks dependencies dynamically
  and automatically reuses subscriptions when read order stays stable. Opt into
  `staticDeps: true` only when every evaluation reads the exact same reactive
  inputs; inactive/closed computations release subscriptions and reconnect when
  observation resumes.
- **Context-local batching:** `Lx.batch` coalesces synchronous notifications;
  `Lx.batchAsync` defers notifications within the current async context without
  blocking unrelated contexts or rolling back writes on error. Check
  `Lx.isBatching` for the current context.
- **Read-only exposure:** Expose `state.asReadable` (`LxReadable<T>`) to
  observation-only consumers so they cannot mutate, refresh, or close the source.

## Async Concurrency & Workers

Async computed values and `LxWorker` accept `LxAsyncConcurrency`:

- `latest` (default): invalidations may overlap and only the latest result is
  published.
- `exhaustLatest`: runs one execution at a time and coalesces intermediate
  changes into one trailing run.

```dart
final results = LxComputed.async(
  () => search(query()),
  concurrency: LxAsyncConcurrency.exhaustLatest,
);
```

Use `LxWorker.withContext` when a side effect can cooperate with cancellation:

```dart
final worker = LxWorker.withContext(query, (value, context) async {
  final hits = await api.search(value, cancelled: context.cancelled);
  context.throwIfCancelled();
  results.value = hits;
});
```

## Re-Bindable Streams & Retained Statuses

`LxStreamCompletionPolicy.close` is the default. Choose `retain` when a
completed stream should preserve its last status and be explicitly rebound:

```dart
final updates = LxStream<int>.idle(
  completionPolicy: LxStreamCompletionPolicy.retain,
);

updates.restartDeferred(() => repository.watchUpdates());
```

`LxStatus.hasLastValue` distinguishes absent data from a successful `null`.
Use `LxWaiting<T>.fromPrevious(status)`, `LxError<T>.fromPrevious(error, stack, status)`,
or `.retained(value)` to preserve nullable prior data (future, stream, and
async computed transitions do this automatically).

## Collection Entries

Read `favorites[id]` or pass `favorites.entry(id)` to observe a single key
(`entry.exists` distinguishes a missing key from a present `null`). A list entry
follows a position through insertions/removals; use a keyed map when identity
must survive reordering. Collections borrow their contents—removing an item
does not close it. For keyed task-backed queries with automatic caching and
eviction, use `LevitAsyncMap` in `levit_dart` / `levit`.

## Asynchronous Lifetimes & Diagnostics

- **Awaited closure:** Reactive `close()` returns `Future<void>`. Closing stops
  notification and admission immediately, drains admitted work and
  subscriptions, and aggregates cleanup failures into `LxCleanupException`.
  Disposal middleware cannot block cleanup.
- **Cancellation vs. drain:** `LxAsyncResource.requestCancel()` signals
  cancellation; `drain()` awaits completion.
- **Middleware (token-based):** Register reactive observers with a stable token
  for idempotent replacement and explicit teardown:

```dart
import 'package:levit_reactive/levit_reactive.dart';

const monitorToken = #state_monitor;

void configure(LevitReactiveMiddleware monitor) {
  Lx.addMiddleware(monitor, token: monitorToken);
}

void teardown() {
  Lx.removeMiddlewareByToken(monitorToken);
}
```

- **Opt-in diagnostics:** Worker statistics default off (`Lx.enableWatchMonitoring`).
  Implement `LevitReactiveMetadataObserver` to observe name, owner, and
  sensitivity updates; mark `isSensitive: true` at construction to redact
  initial creation events.

## Design Principles

- **Ordered propagation:** deterministic notification and batch semantics.
- **Fine-grained tracking:** recompute only what actually read a changed source.
- **Explicit awaited lifetimes:** clean teardown with aggregated errors.
