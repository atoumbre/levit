# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart` adds higher-level pure Dart utilities on top of `levit_dart_core`.

Use this package when you want the utility layer directly.
If you want the recommended app-level single import for pure Dart, use `levit`.

This package is responsible for:

- Controller task execution helpers and lifecycle-aware task orchestration.
- Loop execution helpers for periodic/continuous workloads.
- Focused utility mixins (selection/time helpers) for controller state.

This package does not include:

- Flutter widget bindings (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

The package keeps controller ownership explicit while reducing boilerplate for common operational patterns:

- Queueing and retrying tasks with structured lifecycle events.
- Choosing between engine-only task orchestration and reactive task state.
- Running managed loops tied to controller disposal.

## Getting Started

```yaml
dependencies:
  levit_dart: ^latest
```

```dart
import 'package:levit_dart/levit_dart.dart';

class SyncController extends LevitController with LevitReactiveTasksMixin {
  Future<void> sync() async {
    await runTask(
      () async {
        // perform sync work
      },
      id: 'sync',
    );
  }
}
```

## Choosing a Task Mixin

| Mixin | Use when | Primary API |
| :-- | :-- | :-- |
| `LevitTasksMixin` | You need scheduling, retries, caching, or cancellation without UI-facing reactive task state. | `tasksEngine.schedule(...)` |
| `LevitReactiveTasksMixin` | You want reactive task details, busy state, and progress that can be observed by other runtime code or UI. | `runTask(...)`, `tasks`, `isBusy`, `totalProgress` |

For the next-step design direction for task groups, inherited deadlines, and cancellation trees, see [`proposals/structured_concurrency.md`](../../../proposals/structured_concurrency.md).

## Design Principles

- Controller-first ownership and cleanup.
- Explicit concurrency semantics.
- Reusable utilities without hiding underlying lifecycle mechanics.
