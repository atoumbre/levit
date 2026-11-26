# Live Debugging with `levit_monitor` + `levit_mcp`

`levit_monitor` is opt-in and independent of the kits. Attach it only when you want structured console, file, custom, or live MCP runtime diagnostics.

## 1. Attach `LevitMonitor` to `levit_mcp`

In debug mode, connect your app to the local loopback `levit_mcp` relay using `LevitWebSocketTransport.connect`:

```dart
import 'package:flutter/foundation.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/levit_monitor.dart';

Future<void> main() async {
  Levit.enableAutoLinking();

  if (kDebugMode) {
    final token = const String.fromEnvironment('LEVIT_MCP_TOKEN');
    if (token.isNotEmpty) {
      await LevitMonitor.attach(
        transport: LevitWebSocketTransport.connect(
          const String.fromEnvironment(
            'LEVIT_MCP_URL',
            defaultValue: 'ws://127.0.0.1:9200/ws',
          ),
          appId: 'my_app',
          token: token,
        ),
        historyCapacity: 500,
        enableWorkerStatistics: true,
      );
    }
  }

  runApp(const MyApp());
}
```

- Monitoring does **not** implicitly call `Levit.enableAutoLinking()`. Bootstrap auto-linking explicitly.
- Mark secret values with `.sensitive()` (or configure `LevitMonitor.setObfuscator(...)`) so sensitive values are redacted before leaving the app process.
- Always `await LevitMonitor.detach()` on graceful shutdown when flushing buffered telemetry.

## 2. Configure `levit_mcp` in Your MCP Client

```json
{
  "mcpServers": {
    "levit": {
      "command": "dart",
      "args": ["run", "levit_mcp", "--port", "9200", "--token", "dev-local-token"]
    }
  }
}
```

For Flutter Web debug apps, explicitly allow the local dev server origin:

```bash
levit_mcp --port 9200 --token dev-local-token --allow-web-origin http://localhost:8080
```

## 3. Debugging Workflow with `levit_mcp` Tools

All `levit_mcp` tools are **strictly read-only**:

1. **`list_sessions`** — Confirm the running app(s) are connected and inspect event/error/drop counters.
2. **`diagnose_runtime`** — Fast first check for unowned reactives, scopes stuck in `isClosing`, pending async initializations, high listener counts, recent errors, and dropped telemetry.
3. **`inspect_scope_tree`** — Inspect active DI scopes, parent/child hierarchy, registered dependencies, lazy/factory/async flags, and closing state.
4. **`inspect_reactive_graph`** — Filter reactive variables by `ownerId`, `scopeId`, `nameContains`, or `orphansOnly: true`; trace `LxComputed` upstream dependency edges and listener counts.
5. **`query_timeline`** — Slice recent `LevitMonitor` events by `category` (`di`, `state`, `log`, `custom`), `type`, `scopeId`, `reactiveId`, or `sinceSeq`.
6. **`inspect_task_tree`** — Inspect structured task hierarchies emitted via `LevitMonitor.emitCustomEvent(namespace: 'levit.tasks', name: 'tree', ...)`.

### Bridging Task Events into `levit_monitor`

Because `levit_monitor` does not depend on `levit_dart`, bridge task telemetry in your app composition layer via `LevitMonitor.emitCustomEvent(...)`.

### Security Defaults

- `levit_mcp` binds strictly to `127.0.0.1`, validates `Host` headers, rejects browser `Origin` headers unless explicitly listed in `--allow-web-origin`, and requires a bearer/query token validated in constant time.
- Startup logs print strictly to `stderr` so `stdout` remains reserved for MCP JSON-RPC frames.
