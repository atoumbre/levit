# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit` is the recommended entry point for using the Levit ecosystem in pure Dart.

It is responsible for:
- Providing a single import that composes Levit's reactive engine and dependency injection.
- Including the core controller/store patterns used to structure application logic.
- Shipping higher-level pure Dart utilities from `levit_dart`.

It intentionally does not provide:
- Flutter widget bindings (see `levit_flutter` for Flutter apps).

## Conceptual Overview

Levit is built from composable layers:
- `levit_reactive` provides reactive state primitives.
- `levit_scope` provides dependency injection and deterministic lifecycles.
- `levit_dart_core` provides lifecycle-aware composition (`LevitController`, `LevitStore`, and the `Levit` facade).
- `levit_dart` adds pure Dart utilities (tasks, loops, selection/time helpers).

`levit` bundles these layers behind one import.

## Getting Started

Install:

```yaml
dependencies:
  levit: ^latest
```

Minimal usage:

```dart
import 'package:levit/levit.dart';

void main() {
  final count = 0.lx;
  final log = LxWorker(count, (v) => print('count: $v'));

  final scope = Levit.createScope('app');
  scope.put(() => count, tag: 'count');

  count(1);

  log.close();
  count.close();
  scope.dispose();
}
```

## Design Principles

- Layered composition: use only what you need, from primitives to structured patterns.
- Deterministic lifecycles: scopes own their registrations and dispose them explicitly.
- Pure Dart: suitable for shared domain layers, CLI tools, and backends.
