# levit_mcp

[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_mcp)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

Read-only Model Context Protocol (MCP) server for live Levit runtime inspection.
Requires Dart 3.7+.

`levit_mcp` accepts authenticated loopback WebSocket telemetry from running Dart
and Flutter applications instrumented with `levit_monitor` and exposes structured
runtime inspection tools to MCP-compatible AI agents (Antigravity, Claude Code,
Cursor, Gemini CLI, etc.).

## Features

- **Authenticated loopback relay:** Binds strictly to `127.0.0.1`, validates
  `Host` and `Origin` headers, and requires a shared bearer/query token.
- **Read-only inspection:** Never mutates application state and respects
  `levit_monitor` redaction for sensitive reactives.
- **Six focused MCP tools:**
  - `list_sessions` — Active and recently disconnected app sessions.
  - `inspect_scope_tree` — Live DI scope hierarchy, registrations, and cleanup state.
  - `inspect_reactive_graph` — Redacted reactive variables, `LxComputed` edges, and listener counts.
  - `query_timeline` — Bounded filtered event history with drop accounting.
  - `inspect_task_tree` — Structured task hierarchies from `levit.tasks/tree` events.
  - `diagnose_runtime` — Deterministic anomaly checks (unowned reactives, closing scopes, pending initializations, high listener counts, recent errors, dropped telemetry).
- **MCP resources:** `levit://sessions` and `levit://sessions/{sessionId}/snapshot`.

## Quick Start

### 1. Install and configure your MCP client

Activate globally from pub.dev:

```bash
dart pub global activate levit_mcp
```

Then configure your MCP client:

```json
{
  "mcpServers": {
    "levit": {
      "command": "levit_mcp",
      "args": [
        "--port",
        "9200",
        "--token",
        "dev-local-token"
      ]
    }
  }
}
```

Or activate from a local checkout of the Levit monorepo:

```bash
dart pub global activate --source path /absolute/path/to/levit/packages/tools/levit_mcp
levit_mcp --port 9200 --token dev-local-token
```

If `--token` and `LEVIT_MCP_TOKEN` are omitted, `levit_mcp` generates a 128-bit
cryptographic token and prints it to `stderr`.

### 2. Connect your Dart or Flutter app

```dart
import 'package:levit_monitor/levit_monitor.dart';

Future<void> main() async {
  await LevitMonitor.attach(
    transport: LevitWebSocketTransport.connect(
      'ws://127.0.0.1:9200/ws',
      appId: 'my_app',
      token: 'dev-local-token',
    ),
    historyCapacity: 500,
  );
}
```

For Flutter Web debug sessions, explicitly opt in to the dev-server origin:

```bash
levit_mcp --port 9200 --token dev-local-token --allow-web-origin http://localhost:8080
```
