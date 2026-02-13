# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit` is the recommended single import for pure Dart applications.

This kit re-exports:

- `levit_dart` utility layer.
- `levit_dart_core` composition APIs.
- `levit_scope` and `levit_reactive` foundations (through transitive exports).

Use this package when you want the complete Dart-side Levit stack without Flutter bindings.

## Conceptual Overview

`levit` is intentionally thin.
It does not define new runtime semantics; it packages the Dart stack behind one import for simpler adoption.

## Getting Started

```yaml
dependencies:
  levit: ^latest
```

```dart
import 'package:levit/levit.dart';

void main() {
  final scope = Levit.createScope('app');

  scope.run(() {
    final count = Levit.put(() => 0.lx, tag: 'count');
    final worker = LxWorker(count, (value) => print('count=$value'));

    count(1);

    worker.close();
  });

  scope.dispose();
}
```

## Design Principles

- Zero-surprise aggregation: one import, unchanged underlying APIs.
- Clear boundaries: pure Dart only, no Flutter dependency.
- Production default for shared domain and backend layers.
