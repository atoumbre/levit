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
