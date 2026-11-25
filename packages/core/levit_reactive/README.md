# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_reactive)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_reactive` is Levit's pure Dart reactive runtime.

This package is responsible for:

- Mutable and immutable reactive values.
- Derived state (`LxComputed`, async computed variants).
- Side-effect workers (`LxWorker` family).
- Per-key and per-position collection entries, and replaceable producers (`LxResource`).
- Deterministic propagation and batch semantics.
- Reactive middleware interception.

This package does not include:

- Dependency injection and lifecycle container semantics (`levit_scope`).
- Flutter widget bindings (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

Reactive objects expose values and notify observers.
Observers subscribe implicitly (through dependency tracking) or explicitly (listeners/workers).

Core abstractions:

- `.lx` extensions create reactive sources.
- `LxComputed` defines derived values from dependencies.
- `LxWorker` runs side-effects when dependencies change.
- `Lx.batch` / `Lx.batchAsync` coalesce propagation.

## Getting Started

```yaml
dependencies:
  levit_reactive: ^0.1.0-beta.1
```

```dart
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  final count = 0.lx;
  final doubled = LxComputed(() => count() * 2);

  final worker = LxWorker(doubled, (value) {
    print('doubled=$value');
  });

  count.value = 1;
  count.value = 2;

worker.close();
doubled.close();
count.close();
}
```

## Dynamic computed dependencies

`LxComputed` keeps dynamic tracking enabled by default. When an active computation
reads the same dependencies in the same order, it verifies those reads and reuses
its subscriptions without rebuilding dependency sets. Changed, reordered,
repeated or removed reads are captured normally; upstream graph depth is still
recalculated. This applies to ordinary derived application state without opting
into `staticDeps` or changing consumer behavior. Inactive/closed computations
release their subscriptions and cached dependency order. Static computed values
capture their fixed dependencies again when observation resumes, including reads
after an await in async computations. Ordinary pull-only
reads use a compact getter; optional graph-diagnostic capture stays in a separate
path and still restores the observer context when a calculation throws.

## Async Concurrency

Async computed values and workers accept `LxAsyncConcurrency`:

- `latest` keeps the existing behavior: invalidations may overlap and only the
  latest result is published.
- `exhaustLatest` runs one computation at a time and coalesces any changes that
  arrive while it runs into exactly one trailing computation.

```dart
final results = LxComputed.async(
  () => search(query()),
  concurrency: LxAsyncConcurrency.exhaustLatest,
);
```

## Re-bindable Streams

`LxStreamCompletionPolicy.close` remains the default. Use `retain` when a
completed source should preserve its last status and be explicitly rebound:

```dart
final updates = LxStream<int>.idle(
  completionPolicy: LxStreamCompletionPolicy.retain,
);

updates.restartDeferred(() => repository.watchUpdates());
```

## Observing an address or replacing a producer

Read `favorites[id]` or pass `favorites.entry(id)` to an observer to watch one
key. Use `entry.exists` to distinguish a missing key from a present null.
A list entry follows a position through insertion and removal. Use a map keyed
by ID when a row must follow an entity across reorderings. Collections borrow
their contents; removing an item does not close it.

```dart
final updates = LxResource<LxStatus<int>, LxStream<int>>(
  () => LxStream(repository.watchUpdates()),
);
final listener = updates.stream.listen(render);
await updates.refresh(); // Cancels and drains the old stream before connecting.
await listener.cancel();
await updates.close();
```

The resource starts on first observation. Observers survive replacement. Read
`.producer` for typed domain operations outside replacement. A failed refresh
throws and exposes `refreshError`; `hasLastValue` and `lastValue` preserve prior
data, including null. Refresh again to retry. Closing an unused resource never
constructs its producer.

For custom keyed producers, store explicitly owned resources in
`LxMap<K, LxResource<T, R>>`. The application decides when to remove and close
them. For task-backed loading and automatic retention, use the Dart kit.

### Retained nullable data

`LxStatus.hasLastValue` distinguishes absent data from a successful `null`.
Use `LxWaiting<T>.fromPrevious(status)`, `LxError<T>.fromPrevious(error, stack,
status)` or explicit `.retained(value)` constructors to preserve that distinction.
Future/stream/computed transitions preserve it automatically. Observation-only
consumers accept `LxReadable<T>` and cannot mutate or close their source through
that interface.

## Middleware Lifecycle (Token-Based)

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

## Design Principles

- Ordered, deterministic propagation.
- Fine-grained dependency tracking.
- Explicit lifecycle closure for long-lived resources.
- Predictable middleware interception.

## Reads and batches in 0.0.12

`count()` only reads, including when the value is nullable. Assign with `count.value = next`.

`batchAsync` defers notifications only in the current execution context. Concurrent batches flush independently; nested batches merge into their enclosing open batch. Errors still flush collected changes. Work escaping a completed callback runs under an enclosing open context or ordinary notification delivery. Outside writes notify immediately, even when they affect a shared reactive that another batch touched. Values are shared: batching is not transaction isolation or rollback. `Lx.isBatching` describes the current context.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md) before upgrading.

## 0.1.0 asynchronous lifetimes

Reactive `close()` returns a `Future<void>`. Closing stops notification and
admission immediately; await completion to drain admitted work and subscription
cancellation. `LxAsyncResource.requestCancel()` requests cancellation, while
`drain()` observes completion. A future that ignores cancellation can delay drain.

Use `LxWorker.withContext(source, (value, context) async { ... })` when the
effect can cooperate with cancellation. Check `context.isCancelled`, await
`context.cancelled`, or call `context.throwIfCancelled()` before publishing an
external effect. `latest` cancels previous contexts but drains every started
callback. Worker convenience callbacks preserve returned futures.

`LxReadable<T>` exposes observation without refresh, close, or metadata setters.
`LxState.asReactive` now returns this observation-only interface. It does not
make the contained value immutable.

### Optional diagnostics

Worker statistics default off. Enable `Lx.enableWatchMonitoring` explicitly, or
use `LevitMonitor.attach(enableWorkerStatistics: true)` during an inspector session.
The monitor restores the previous flag on detach. Optional
`LevitReactiveMetadataObserver` receives name, owner and sensitivity changes without
adding required methods to existing reactive middleware implementations. Mark
sensitivity at construction to redact initialization events.

Disposal middleware cannot prevent resource cleanup. `close()` stops observation,
drains bindings and producer work, and reports all cleanup failures together in
`LxCleanupException`. Cancellation alone does not complete that future.
