# levit_monitor

[![Pub Version](https://img.shields.io/pub/v/levit_monitor)](https://pub.dev/packages/levit_monitor)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_monitor)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_monitor)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_monitor` is the opt-in diagnostics, redaction, snapshot, and event export
layer for Levit runtimes. It is intentionally **not** bundled by `levit` or
`levit_flutter` and has no dependency on `levit_dart`.

Add `levit_monitor` when you need:

- Structured DI and reactive telemetry for debugging, QA, or production logs.
- Privacy-aware obfuscation before events leave the process.
- Pluggable transports (console, WebSocket, file, multi-transport, or custom).
- Bounded redacted shadow state (`LevitMonitor.snapshot`) and optional history.

## Getting Started

```yaml
dependencies:
  levit: ^0.1.0
  levit_monitor: ^0.1.0
```

```dart
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  LevitMonitor.setFilter(
    (event) => event is! LevitReactiveEvent || event.reactive.name != 'secret',
  );
  await LevitMonitor.attach(
    transport: LevitConsoleTransport(),
  );
}
```

Event flow: runtime emits DI/reactive/custom event → filter → obfuscator &
immutable JSON envelope capture → bounded transport queue.

## Custom Events

Application adapters can feed structured domain events (such as `levit_dart`
task events) into the filter, redaction, snapshot, and transport pipeline
without coupling `levit_monitor` to higher-level packages:

```dart
LevitMonitor.emitCustomEvent(
  namespace: 'my_app.sync',
  name: 'finished',
  level: LevitLogLevel.info,
  attributes: {
    'category': 'background',
    'outcome': 'succeeded',
    'runMs': 48,
  },
);
```

- Pass `sensitive: true` to redact the full attribute payload and error details.
- Primitives, lists, maps, `DateTime`, `Duration`, and `Uri` serialize directly;
  other objects fall back to `toJson` or safe stringification, with cycle and
  non-finite number guards.
- See [example/task_adapter.dart](https://github.com/softilab/levit/blob/main/packages/core/levit_monitor/example/task_adapter.dart)
  for bridging a `LevitTaskEngine` to `levit.tasks/tree` custom events.

## Awaited Lifecycle, Redaction & Retention

- **Awaited attach/detach:** `attach`, `flush`, `detach`, `updateTransport`, and
  transport `close` all return futures. Transport failures never corrupt
  application state and are aggregated in `LevitMonitorException` on awaited
  `flush` / `detach`.
- **Explicit bootstrap:** Attaching monitoring never enables auto-linking; call
  `Levit.enableAutoLinking()` explicitly during app startup.
- **Redaction at construction:** Set `isSensitive: true` when constructing a
  reactive (for example `LxVar(token, isSensitive: true)`) so the creation event
  is redacted before buffering or retention.
- **Bounded defaults:** History (`historyCapacity: 0`) and worker statistics
  (`enableWorkerStatistics: false`) default off; `maxPendingEvents` defaults to
  `1024`. `LevitWebSocketTransport` buffers up to `256` events with sequence
  acknowledgements (5s timeout), drop accounting (`droppedEvents`), and
  reconnect snapshots (`historyComplete: false`). Optional
  `includeStackTrace: true` captures write call stacks.

## Platform Imports & Live MCP Inspection

- **Browser-safe default:** `package:levit_monitor/levit_monitor.dart` and
  `package:levit_monitor/levit_monitor_protocol.dart` contain no `dart:io`
  imports. Import `package:levit_monitor/levit_monitor_io.dart` for
  `LevitFileTransport`.
- **Custom transports:** Extend `LevitTransport` to consume frozen
  `LevitMonitorEvent` envelopes and implement awaitable `flush` and `close`.
- **Live AI agent inspection:** Connect a running app via
  `LevitWebSocketTransport.connect('ws://127.0.0.1:9200/ws', appId: 'my-app', token: 'dev-local-token')`
  to [levit_mcp](https://github.com/softilab/levit/blob/main/packages/tools/levit_mcp/README.md)
  for read-only scope, reactive graph, timeline, task tree, and diagnostic tools.

## Wire Protocol & Snapshots

`LevitMonitor.snapshot` (`LevitStateSnapshot`) maintains immutable, value-free
dependency metadata and redacted reactive state reconstructed from frozen
`LevitEventEnvelope` records (`LevitEventEnvelope.capture` /
`LevitEventEnvelope.stateChange`). Derived `scope_progress` events (`version: 1`)
emit complete scope records whenever ownership or initialization state changes,
so dropped earlier frames never produce partial deltas. See the inline DartDoc
in `package:levit_monitor/levit_monitor_protocol.dart` and
`package:levit_monitor/spi.dart` for exact wire schemas and flag layouts.

## Design Principles

- **Opt-in instrumentation:** explicit attach/detach with zero cost when unused.
- **Privacy by default:** redaction runs before buffering, snapshots, or export.
- **Transport-agnostic delivery:** bounded queues with explicit drop accounting.
