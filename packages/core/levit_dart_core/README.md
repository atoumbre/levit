# levit_dart_core

[![Pub Version](https://img.shields.io/pub/v/levit_dart_core)](https://pub.dev/packages/levit_dart_core)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart_core` is the composition layer that integrates `levit_scope` (dependency injection and lifecycles) with `levit_reactive` (reactive state primitives).

It is responsible for:
- Providing lifecycle-aware building blocks for application logic.
- Offering a single entry point (`Levit`) to interact with scopes and reactive batching.
- Supporting deterministic cleanup through controller ownership and auto-disposal.

It intentionally does not provide:
- Flutter widget bindings (see `levit_flutter_core` / `levit_flutter`).
- Higher-level task and loop utilities (see `levit_dart`).

## Conceptual Overview

`levit_dart_core` formalizes how state and side effects are owned.
Two common patterns are:
- Controllers (`LevitController`) for long-lived business logic with an explicit lifecycle.
- Stores (`LevitStore`) for reusable, lazy-initialized state factories scoped to a `LevitScope`.

## Getting Started

Install:

```yaml
dependencies:
  levit_dart_core: ^latest
```

Minimal usage:

```dart
import 'package:levit_dart_core/levit_dart_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() => count(count() + 1);
}

void main() {
  final scope = Levit.createScope('app');

  scope.run(() {
    Levit.put(() => CounterController());
    final controller = Levit.find<CounterController>();
    controller.increment();
  });
}
```

## Design Principles

- Ownership is explicit: reactive objects can be tied to controller lifecycles and disposed deterministically.
- Composition over magic: the `Levit` facade exposes scope and reactive operations without hiding scoping rules.
- Pure Dart: the package has no Flutter dependency and can be used in shared domain layers and backends.
