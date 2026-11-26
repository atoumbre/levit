# levit_devtools

[![Pub Version](https://img.shields.io/pub/v/levit_devtools)](https://pub.dev/packages/levit_devtools)
[![Platforms](https://img.shields.io/badge/platforms-flutter%20%7C%20dart-blue)](https://pub.dev/packages/levit_devtools)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

Read-only Flutter DevTools extension and Dart VM Service transport for live
Levit runtime inspection. Requires Dart 3.7+.

## Features

- **Zero-server connection:** Uses the Dart VM Service protocol
  (`dart:developer` `registerExtension` and `postEvent`)—works automatically on
  iOS, Android, macOS, Windows, Linux, emulators, and Flutter Web without ports,
  tokens, or CORS configuration.
- **Strictly read-only & privacy-safe:** Respects `levit_monitor` redaction for
  `isSensitive: true` reactives and never mutates application state.
- **Five focused DevTools tabs:**
  - **Scopes** — Live DI scope hierarchy, registrations, aliases, and closing state.
  - **Reactives** — Filterable redacted reactive variables, listener counts, and computed dependency edges.
  - **Tasks** — Active task groups bridged via `levit.tasks/tree` custom events.
  - **Timeline** — Live searchable, pausable event stream with JSON detail view.
  - **Diagnostics** — Live deterministic anomaly checks shared with `levit_mcp` (`unowned_reactives`, `closing_scopes`, `pending_initializations`, `high_listener_count`, `recent_errors`, `dropped_telemetry`).

## Quick Start

Add `levit_devtools` to your app:

```yaml
dependencies:
  levit_flutter: ^0.1.0
  levit_devtools: ^0.1.0
```

Attach in `main()` before `runApp` (automatically a no-op in `--release` builds):

```dart
import 'package:flutter/material.dart';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:levit_flutter/levit_flutter.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  await LevitDevTools.attach();
  runApp(const MyApp());
}
```

Then open **Flutter DevTools** and select the **levit_devtools** tab.

## Composing with Other Transports

Pass additional transports (such as `LevitConsoleTransport` or
`LevitWebSocketTransport` for `levit_mcp`) to `LevitDevTools.attach`:

```dart
await LevitDevTools.attach(
  extraTransports: [LevitConsoleTransport()],
  historyCapacity: 500,
);
```

Or wire `LevitVmServiceTransport` directly into `LevitMonitor.attach(...)`.
