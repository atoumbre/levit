# levit_monitor

[![Pub Version](https://img.shields.io/pub/v/levit_monitor)](https://pub.dev/packages/levit_monitor)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_monitor)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_monitor)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_monitor` is the monitoring and diagnostics layer for the Levit ecosystem.

It is responsible for:
- Capturing structured events from dependency injection and reactive state systems.
- Filtering and obfuscating event payloads before export.
- Dispatching events to one or more transports.

It intentionally does not provide:
- UI tooling (it emits data; you decide how to visualize or store it).

## Conceptual Overview

Monitoring is opt-in.
Attaching `LevitMonitor` installs middleware that observes Levit activity and forwards events through a transport pipeline:

1. Events are produced by the Levit runtime.
2. An optional filter decides whether an event is exported.
3. An obfuscator can hide sensitive values.
4. Transports deliver the events (console, file, WebSocket, or custom).

## Getting Started

Install:

```yaml
dependencies:
  levit_monitor: ^latest
```

Minimal usage:

```dart
import 'package:levit_monitor/levit_monitor.dart';

void main() {
  LevitMonitor.attach();

  // Optional: reduce noise or exclude sensitive sources.
  LevitMonitor.setFilter((event) => true);
}
```

## Design Principles

- Opt-in observability: monitoring is disabled until attached.
- Privacy by default: sensitive values can be obfuscated consistently.
- Transport-agnostic: export is defined by the `LevitTransport` interface.
