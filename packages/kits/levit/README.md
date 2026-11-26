# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit` is the recommended single import for pure Dart applications (CLI tools,
servers, background workers, and shared domain packages).

It re-exports the complete Dart-side Levit stack without redefining runtime
semantics. Add `levit_monitor` separately when you need runtime telemetry; the
kit keeps observability opt-in.

## What's Included

| Entry point | Provides |
| :-- | :-- |
| `package:levit/levit.dart` | `Levit` facade, hierarchical `LevitScope`, `LevitController`, `LevitStore` / `LevitAsyncStore`, reactive values (`LxVar`, `LxComputed`, `LxFuture`, `LxStream`, `LxWorker`, collections), `LevitAsyncMap`, and controller mixins (`LevitTasksMixin`, `LevitReactiveTasksMixin`, `LevitTimeMixin`, `LevitSelectionMixin`, `LevitLoopMixin`). |
| `package:levit/tasks.dart` | Advanced task orchestration types: `LevitTaskGroup`, `LevitRetryPolicy`, `LevitTaskMiddleware`, `LevitTaskTracker`, and task cache/engine APIs. |
| `package:levit/levit_testing.dart` | `LevitTestScope` for isolated store overrides, explicit async tracking (`track` / `settle`), and awaited teardown. |

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
    // Explicit ownership when Levit.enableAutoLinking() is not enabled.
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

- **Zero-surprise aggregation:** one import, unchanged underlying APIs.
- **Pure Dart boundary:** no Flutter dependency.
- **Production default:** built for shared domain logic, CLIs, and backend services.

Continue with [ownership-first onboarding](https://github.com/softilab/levit/blob/main/docs/ONBOARDING.md) and
[advanced helpers](https://github.com/softilab/levit/blob/main/docs/ADVANCED.md). Requires Dart 3.7+.
