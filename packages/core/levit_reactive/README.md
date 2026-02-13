# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_reactive)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_reactive` is Levit's pure Dart reactive runtime.

This package is responsible for:

- Mutable and immutable reactive values.
- Derived state (`LxComputed`, async computed variants).
- Side-effect workers (`LxWorker` family).
- Deterministic propagation and batch semantics.
- Reactive middleware interception.

This package does not include:

- Dependency injection and lifecycle container semantics (`levit_scope`).
- Flutter widget bindings (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

Reactive objects expose values and notify observers.
Observers subscribe implicitly (through dependency tracking) or explicitly (listeners/workers).

Core abstractions:

- `.lx` extensions create reactive sources.
- `LxComputed` defines derived values from dependencies.
- `LxWorker` runs side-effects when dependencies change.
- `Lx.batch` / `Lx.batchAsync` coalesce propagation.

## Getting Started

```yaml
dependencies:
  levit_reactive: ^latest
```

```dart
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  final count = 0.lx;
  final doubled = LxComputed(() => count() * 2);

  final worker = LxWorker(doubled, (value) {
    print('doubled=$value');
  });

  count(1);
  count(2);

  worker.close();
  doubled.close();
  count.close();
}
```

## Middleware Lifecycle (Token-Based)

```dart
import 'package:levit_reactive/levit_reactive.dart';

const historyToken = #state_history;

void configure() {
  Lx.addMiddleware(LevitReactiveHistoryMiddleware(), token: historyToken);
}

void teardown() {
  Lx.removeMiddlewareByToken(historyToken);
}
```

## Design Principles

- Ordered, deterministic propagation.
- Fine-grained dependency tracking.
- Explicit lifecycle closure for long-lived resources.
- Predictable middleware interception.

