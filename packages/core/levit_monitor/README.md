# levit_monitor

[![Pub Version](https://img.shields.io/pub/v/levit_monitor)](https://pub.dev/packages/levit_monitor)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_monitor)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_monitor)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_monitor` is the diagnostics and event export layer for Levit runtimes.

This package is responsible for:

- Capturing structured runtime events from DI and reactive layers.
- Filtering and obfuscating payloads before export.
- Dispatching events through pluggable transports.
- Maintaining current diagnostic state and optional bounded event history.

This package does not include:

- Visualization UI or dashboards.
- Business logic instrumentation outside the Levit runtime event model.
- Dependencies on higher-level kits such as `levit_dart`.

## Conceptual Overview

Monitoring is opt-in.
Awaiting `LevitMonitor.attach()` installs middleware into the runtime after previous attachment cleanup.
Event flow:

1. Runtime emits DI/reactive events.
2. Filter decides whether to forward the event.
3. Obfuscator redacts sensitive values; serialization freezes immutable JSON envelopes.
4. Bounded queues deliver those envelopes and account for discarded events.

## When to Add This Package

Add `levit_monitor` when you need:

- Structured runtime telemetry for debugging, QA, or production diagnostics.
- Event export to a console, socket, file, or custom transport.
- Redaction and shadow-state support before events leave the process.

You do not need it for normal application logic, and it is intentionally not bundled by `levit` or `levit_flutter`.

## Getting Started

```yaml
dependencies:
  levit: ^0.1.0-beta.1
  levit_monitor: ^0.1.0-beta.1
```

```dart
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  LevitMonitor.setFilter((event) =>
      event is! ReactiveEvent || event.reactive.name != 'secret');
  await LevitMonitor.attach(
    transport: ConsoleTransport(),
  );
}
```

## Design Principles

- Opt-in instrumentation with explicit attach/detach lifecycle.
- Transport-agnostic event delivery.
- Privacy-aware output through obfuscation hooks.
- Low-friction integration with existing Levit middleware semantics.

## Custom Events

Adapters can feed structured events into the existing filter, redaction,
snapshot cache, and transport pipeline without adding a package dependency to
`levit_monitor`:

```dart
LevitMonitor.emitCustomEvent(
  namespace: 'my_app.sync',
  name: 'finished',
  level: Level.info,
  attributes: {
    'category': 'background',
    'outcome': 'succeeded',
    'runMs': 48,
  },
);
```

Use stable namespace, name, and low-cardinality attribute values. Setting
`sensitive: true` redacts the complete attribute payload plus error details.
The producer owns translation from its domain event; `levit_monitor` remains
unaware of that producer's types.

Custom attributes preserve JSON-safe primitive, map, list, `DateTime`,
`Duration`, and `Uri` values. Unsupported values are safely stringified.
Transport failures remain isolated from application state changes and propagate through awaited `flush`/`detach` as `LevitMonitorException`, after all cleanup attempts.

Task/controller packages should expose their own dependency-neutral events.
Applications that import both packages may translate those events here;
`levit_monitor` intentionally does not depend on `levit_dart`.

Monitoring preserves the application’s explicit auto-linking configuration.
Call `Levit.enableAutoLinking()` during application bootstrap when relying on captured reactive ownership.

## Awaited lifecycle and retention

`attach`, `flush`, `detach`, middleware `updateTransport` and transport `close`
return futures. Await replacement and shutdown. Detach stops admission, drains
accepted sends, then releases every sink; failures are aggregated. Middleware
transport replacement attempts old delivery and cleanup, installs the new sink,
sends its snapshot, then reports accumulated failures. Global attachment fails
without installing a new monitor if the preceding attachment cannot close cleanly.

History is **off by default** (`historyCapacity: 0`), as are worker statistics.
Enable `historyCapacity` and `enableWorkerStatistics` for inspector sessions;
detach restores the previous statistics flag. `maxPendingEvents` defaults to 1024.
`WebSocketTransport` has a bounded queue (256), sequence acknowledgements and a
five-second acknowledgement deadline. Disconnection or overflow accounts for
lost delivery through `droppedEvents`; `flush` waits for delivery or an accounted
drop and for actual socket cleanup. It does not promise durable receipt.

`LevitMonitor.snapshot` contains immutable, value-free dependency descriptions and
redacted reactive state. `history` contains immutable `LevitEventEnvelope` objects,
never live application objects. Reconnect snapshots replace remote state and
explicitly set `historyComplete: false`. Optional `includeStackTrace: true` records
write call stacks, in addition to update values, ownership and dependency graphs.

Set sensitivity **at construction**, for example
`LxVar(token, isSensitive: true)`, so the initial event is redacted too. Changing
sensitivity later cannot retract events already delivered. Custom events use
`sensitive: true` to redact attributes and error details before retention.

## Local inspector and platform imports

Run the optional `levit_devtools` CLI, then attach with
`WebSocketTransport.connect('ws://127.0.0.1:9200/ws', appId: 'my-app')`.
The standalone tool includes sessions, ownership/reactions, update details, pending
cleanup, optional task trees, filtering, a bounded timeline and redacted JSON export.
See [levit_devtools](../../tools/levit_devtools/README.md).

The default library and `levit_monitor_protocol.dart` support browsers. File output
is IO-only: import `package:levit_monitor/levit_monitor_io.dart` for `FileTransport`.
Custom transports extend `LevitTransport`, accept frozen `MonitorEvent` envelopes,
and implement awaitable `flush` and `close` for any buffered work.
Synchronous `send` implementations drain without a future per event; asynchronous
sends remain ordered and are awaited before subsequent sends and shutdown.
Envelope capture copies and freezes ordinary JSON directly, detects cycles and
rejects non-finite/unsupported data. Custom `toJson` conversion remains supported
through the JSON encoder; redaction still happens before buffering or retention.

WebSocket shutdown drains subscription cancellation and socket closure, including
failure paths after disconnect. Cleanup failures propagate from awaited `flush`
or `close`; they are not sent to an unrelated asynchronous error handler.

[example/task_adapter.dart](example/task_adapter.dart) demonstrates a borrowing
application bridge from a task engine to `levit.tasks/tree` custom events. Own it
after its engine so it unsubscribes before the engine is released. Runtime monitor
packages have no dependency on the task kit.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md).

Scope progress retains changed ownership/initialization/cleanup snapshots;
identical consecutive descriptions do not emit another derived progress event.
This does not suppress dependency lifecycle events or count as a transport drop.
The final empty closing/disposed descriptions are represented by the following
`scope_dispose` event, emitted only after cleanup finishes, including failure
paths. Scope create/dispose events contain scope identity, without unused
dependency flags. Progress for any unfinished owned work remains explicit.
The `scope_progress` wire event uses `version: 1` and a compact `scope` record:
`[id, name, flags, pendingInitializations, ancestry, ownedChildren, registrations]`.
Scope flags are closing=1 and disposed=2. Ancestors and children are `[id, name]`;
registrations are `[key, type, aliasOf, flags, pendingInitializations, ownedInstances]`,
with factory=1, async=2, lazy=4, permanent=8, instantiated=16 and closing=32.
Every record is complete. Dropped earlier records cannot leave a partial delta.
`StateSnapshot` expands it to the usual named fields for the inspector and JSON
snapshots; unsupported wire versions fail explicitly.
Immutable capture reuses the event timestamp and freezes private JSON copies;
custom wire timestamp overrides still round-trip. `LevitEventEnvelope(data,
category: 'custom')` supplies a default category while preserving an explicit
category in `data`. The input and all nested containers remain detached.

`LevitEventEnvelope.capture((fields) => fields..['type'] = 'custom')` freezes
each assigned value and seals the supplied map when the callback returns or
throws. Retaining that map cannot mutate a captured event. Returning another map
uses defensive copying. State-change envelopes use a shared immutable field
layout with the same JSON fields; `LevitEventEnvelope.stateChange` accepts only
already-redacted scalar metadata. Custom event serialization remains supported.
