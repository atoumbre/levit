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
- Maintaining optional in-memory shadow state for debugging workflows.

This package does not include:

- Visualization UI or dashboards.
- Business logic instrumentation outside the Levit runtime event model.
- Dependencies on higher-level kits such as `levit_dart`.

## Conceptual Overview

Monitoring is opt-in.
Calling `LevitMonitor.attach()` installs middleware into the runtime.
Event flow:

1. Runtime emits DI/reactive events.
2. Filter decides whether to forward the event.
3. Obfuscator redacts sensitive values.
4. Transport(s) deliver encoded events.

## When to Add This Package

Add `levit_monitor` when you need:

- Structured runtime telemetry for debugging, QA, or production diagnostics.
- Event export to a console, socket, file, or custom transport.
- Redaction and shadow-state support before events leave the process.

You do not need it for normal application logic, and it is intentionally not bundled by `levit` or `levit_flutter`.

## Getting Started

```yaml
dependencies:
  levit_monitor: ^latest
```

```dart
import 'package:levit_monitor/levit_monitor.dart';

void main() {
  LevitMonitor.attach(
    transport: ConsoleTransport(),
    filter: (event) => true,
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
Transport or adapter failures remain isolated from application work.

Task/controller packages should expose their own dependency-neutral events.
Applications that import both packages may translate those events here;
`levit_monitor` intentionally does not depend on `levit_dart`.
