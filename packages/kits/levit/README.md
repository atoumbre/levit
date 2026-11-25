# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit` is the recommended single import for pure Dart applications.

This kit re-exports:

- `levit_dart` utility layer.
- `levit_dart_core` composition APIs.
- `levit_scope` and `levit_reactive` foundations (through transitive exports).

Use this package when you want the complete Dart-side Levit stack without Flutter bindings.
Add `levit_monitor` separately when you need runtime telemetry; the kit keeps observability opt-in.

## Conceptual Overview

`levit` is intentionally thin.
It does not define new runtime semantics; it packages the Dart stack behind one import for simpler adoption.

## Getting Started

```yaml
dependencies:
  levit: ^0.1.0-beta.1
```

```dart
import 'package:levit/levit.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  @override
  void onInit() {
    super.onInit();
    own(count);
  }
  void increment() => count.value++;
}

Future<void> main() async {
  final scope = Levit.createScope('app');

  try {
    final controller = scope.put(() => CounterController());
    controller.increment();
    print(controller.count.value);
  } finally {
    await scope.dispose();
  }
}
```

## Design Principles

- Zero-surprise aggregation: one import, unchanged underlying APIs.
- Clear boundaries: pure Dart only, no Flutter dependency.
- Production default for shared domain and backend layers.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md) before upgrading.

Continue with [ownership-first onboarding](../../../docs/ONBOARDING.md) and
[advanced helpers](../../../docs/ADVANCED.md). Requires Dart 3.12+.
