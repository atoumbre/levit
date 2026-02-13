# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Purpose & Scope

`levit_dart` adds higher-level pure Dart utilities on top of `levit_dart_core`.

This package is responsible for:

- Controller task execution helpers and lifecycle-aware task orchestration.
- Loop execution helpers for periodic/continuous workloads.
- Focused utility mixins (selection/time helpers) for controller state.

This package does not include:

- Flutter widget bindings (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

The package keeps controller ownership explicit while reducing boilerplate for common operational patterns:

- Queueing and retrying tasks with structured lifecycle events.
- Tracking execution status reactively.
- Running managed loops tied to controller disposal.

## Getting Started

```yaml
dependencies:
  levit_dart: ^latest
```

```dart
import 'package:levit_dart/levit_dart.dart';

class SyncController extends LevitController with LevitTasksMixin {
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

## Design Principles

- Controller-first ownership and cleanup.
- Explicit concurrency semantics.
- Reusable utilities without hiding underlying lifecycle mechanics.

