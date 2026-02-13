# nexus_studio_shared

Pure Dart shared domain runtime for the `nexus_studio` example.

## Purpose & Scope

This package centralizes environment-agnostic domain behavior used by both the Flutter app and the Dart server.

It is responsible for:

- Domain state models and command application rules.
- Reactive derivations that both runtimes consume consistently.
- Shared contracts that keep client and server behavior aligned.

It deliberately excludes:

- Flutter UI concerns.
- Server transport/session orchestration concerns.

## Conceptual Overview

`shared` is the canonical business-logic source for Nexus Studio.
Both app and server import this package so state transitions and validation logic remain consistent across runtimes.

## Getting Started

```yaml
dependencies:
  nexus_studio_shared:
    path: ../shared
```

## Usage

Import shared contracts and runtime types from:

```dart
import 'package:nexus_studio_shared/shared.dart';
```

Use these APIs from app/server layers instead of duplicating business logic.

## Design Principles

- Environment-agnostic business logic.
- Single source of truth for state transitions.
- Deterministic behavior across client/server execution.
