# Nexus Studio

`nexus_studio` is the advanced reference application for multi-package Levit architecture.

## Purpose & Scope

This example demonstrates how to structure a collaborative, stateful system with shared domain logic across Flutter and Dart server runtimes.

It is responsible for showcasing:

- Isomorphic domain logic in a pure Dart shared package.
- Deterministic reactive state transitions across app/server boundaries.
- Runtime coordination between transport, validation, and projection layers.

## Project Structure

- [`shared/`](./shared): shared domain models, commands, and reactive engine.
- [`server/`](./server): authoritative session runtime and broadcast layer.
- [`app/`](./app): Flutter client UI and intent dispatch.

## Conceptual Overview

The architecture separates responsibilities clearly:

- Shared logic defines the canonical state model and transition rules.
- Server validates and applies commands, then publishes state updates.
- Client renders projected state and emits user intent.

This keeps core behavior consistent between environments while preserving clear operational boundaries.

## Getting Started

### One-step launcher (macOS/Linux)

```bash
./run.sh
```

### Manual startup

1. Start server:

```bash
cd server
dart run bin/server.dart
```

2. Start app:

```bash
cd ../app
flutter run
```

## Verification

```bash
cd shared && dart test
cd ../server && dart test
cd ../app && flutter test
```


## Local commands in 0.1.0

`NexusCommandHistory` retains at most 100 immutable domain commands. Creation,
position and color edits have explicit inverse messages. Drag updates are previews;
ending a drag commits one command. Execute/undo/redo update state in one synchronous
batch. A new edit clears redo. Received document updates and snapshots clear local
history; presence messages do not. `node_create` and `node_delete` are idempotent
by node ID. This is local undo, with inverses synchronized over the existing server
protocol; it does not merge competing collaborative undo histories.

Regression coverage lives in `shared/test/command_history_test.dart` and
`server/test/two_client_undo_test.dart`, which starts a real loopback WebSocket
server and checks both clients and the authoritative document after undo/redo.

## Local inspector (0.1.0)

Run `dart run bin/levit_devtools.dart` from `packages/tools/levit_devtools`, then
open http://127.0.0.1:9200. The app and server appear as separate sessions. Debug
attachments opt in to bounded history, worker statistics and update call stacks.
Both support the compile-time `LEVIT_INSPECTOR_URL` define for an alternate relay.
For example, run Flutter with
`--dart-define=LEVIT_INSPECTOR_URL=ws://127.0.0.1:9201/ws` and Dart with
`-DLEVIT_INSPECTOR_URL=ws://127.0.0.1:9201/ws`.
