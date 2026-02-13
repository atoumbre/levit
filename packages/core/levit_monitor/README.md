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

## Conceptual Overview

Monitoring is opt-in.
Calling `LevitMonitor.attach()` installs middleware into the runtime.
Event flow:

1. Runtime emits DI/reactive events.
2. Filter decides whether to forward the event.
3. Obfuscator redacts sensitive values.
4. Transport(s) deliver encoded events.

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

