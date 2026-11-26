## 0.1.0

- Initial release of `levit_mcp`, the read-only Model Context Protocol (MCP) server for live Levit runtime inspection.
- Accepts authenticated loopback `LevitWebSocketTransport` connections from running Dart and Flutter apps.
- Exposes `list_sessions`, `inspect_scope_tree`, `inspect_reactive_graph`, `query_timeline`, `inspect_task_tree`, and `diagnose_runtime` MCP tools plus session snapshot resources.
