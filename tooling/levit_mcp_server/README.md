# levit_mcp_server

`levit_mcp_server` is a stdio-based MCP server for Levit.

## Features

- Implements MCP JSON-RPC over stdio (`initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`).
- Exposes Levit-oriented tools:
  - `levit_workspace_scan`: scan workspace packages.
  - `levit_api_lookup`: find Dart symbol references in Levit package source.
  - `levit_docs_search`: search README/CHANGELOG docs.
  - `levit_affected_packages`: infer affected packages from changed paths or git status.
  - `levit_analyze_packages`: dry-run or run `dart analyze` on selected/affected packages.
  - `levit_reactive_simulate`: run a deterministic reactive simulation.
- Exposes MCP resources:
  - `levit://workspace/packages`
  - `levit://workspace/affected_packages`

## Run

From this package directory:

```bash
dart run bin/levit_mcp_server.dart
```

## Configure in an MCP client

Example command:

```json
{
  "command": "dart",
  "args": ["run", "bin/levit_mcp_server.dart"],
  "cwd": "/Users/atoumbre/SoftiLab/levit-svg/packages/tooling/levit_mcp_server"
}
```
