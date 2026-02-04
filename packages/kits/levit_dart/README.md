# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart` is the pure Dart utilities layer for Levit controllers and application logic.

It is responsible for:
- Providing task execution and tracking utilities for controllers.
- Providing loop/execution helpers for periodic or continuous work.
- Providing small controller-focused helpers (time and selection utilities).

It intentionally does not provide:
- Flutter widget bindings (see `levit_flutter_core` / `levit_flutter`).

## Conceptual Overview

`levit_dart` builds on `levit_dart_core`.
Controllers remain responsible for business logic and lifecycle; this package adds reusable engines and mixins that standardize common patterns such as:
- Running cancellable tasks with retry/priority policies.
- Tracking task state reactively when needed (for UIs or other observers).
- Managing periodic execution loops tied to controller lifecycles.

## Getting Started

Install:

```yaml
dependencies:
  levit_dart: ^latest
```

Minimal usage:

```dart
import 'package:levit_dart/levit_dart.dart';

class RefreshController extends LevitController with LevitReactiveTasksMixin {
  Future<void> refresh() async {
    await runTask(
      () async {
        // Do work here.
      },
      id: 'refresh',
    );
  }
}
```

## Design Principles

- Controller-first: utilities are designed to be owned and disposed by `LevitController`.
- Explicit concurrency: tasks and loops are configured intentionally rather than hidden behind implicit behavior.
- Pure Dart: usable outside Flutter; `levit_flutter` integrates these utilities with widgets.
