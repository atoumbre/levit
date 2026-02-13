
# Levit

**A deterministic reactive foundation for Dart and Flutter.**
Lean by design. Fast by default. Explicit by choice.

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg)](https://codecov.io/github/atoumbre/levit)

Levit is a layered ecosystem that combines:
- Fine-grained synchronous reactivity (`levit_reactive`)
- Hierarchical dependency injection with deterministic lifecycles (`levit_scope`)
- Explicit Flutter widget bindings (`levit_flutter_core`)

It is designed for teams that value predictable lifecycles and explicit boundaries over implicit global state and hidden subscriptions.

## Installation

### Flutter Applications

```bash
flutter pub add levit_flutter
```

### Pure Dart (Logic, CLI, Server)

```bash
dart pub add levit
```

## Quick Start

### Pure Dart

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

### Flutter

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count(count() + 1);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView<CounterController>.put(
      () => CounterController(),
      builder: (context, controller) => Scaffold(
        body: Center(
          child: LWatch(() => Text('Count: ${controller.count()}')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

void main() => runApp(const MaterialApp(home: CounterPage()));
```

## Ecosystem Overview

Levit is modular and can be adopted incrementally.

### Kits (Recommended Entry Points)

| Package                                      | Use case |
| :------------------------------------------- | :------- |
| [`levit_flutter`](./packages/kits/levit_flutter) | Flutter applications |
| [`levit`](./packages/kits/levit)                 | Pure Dart applications and shared domain layers |

### Core Packages

| Package                                            | Responsibility |
| :------------------------------------------------- | :------------- |
| [`levit_reactive`](./packages/core/levit_reactive) | Reactive state primitives and dependency tracking |
| [`levit_scope`](./packages/core/levit_scope)       | Dependency injection and deterministic lifecycles |
| [`levit_dart_core`](./packages/core/levit_dart_core) | Composition layer for controllers and stores |
| [`levit_flutter_core`](./packages/core/levit_flutter_core) | Flutter widget bindings for scopes and reactive rebuilds |
| [`levit_monitor`](./packages/core/levit_monitor)   | Monitoring and diagnostics event pipeline |

## Architecture at a Glance

```mermaid
---
config:
  layout: elk
---
flowchart LR
 subgraph Kits["Kits"]
        LevitFlutter["levit_flutter"]
        LevitDart["levit"]
  end
 subgraph AppLogic["Application Logic"]
        DartCore["levit_dart_core"]
        FlutterCore["levit_flutter_core"]
        Monitor["levit_monitor"]
  end
 subgraph Foundations["Foundations"]
        Reactive["levit_reactive"]
        Scope["levit_scope"]
  end
    LevitDart --> DartCore
    DartCore --> Reactive & Scope
    Monitor -.-> Reactive & Scope
    LevitFlutter --> FlutterCore
    FlutterCore --> DartCore
```

## Decision Shortcuts

Use these defaults for consistent architecture choices:

- **Logic:** `LevitController` for lifecycle orchestration; `LevitStore<T>` for sync state recipes; `LevitAsyncStore<T>` for async recipes.
- **Scopes:** `put` for eager registrations, `lazyPut` for sync lazy singletons/factories, `lazyPutAsync` for async lazy registrations (no `putAsync`).
- **Scoped tests/utilities:** `Levit.runInScope(() { ... })` for temporary child scopes with automatic teardown.
- **Task diagnostics:** use `LevitTaskEngine(onTaskEvent: ...)` (or `LevitTasksMixin.onTaskEvent`) to trace queue/start/retry/finish/skip/fail transitions.
- **Flutter rebuilds:** `LBuilder` / `LSelectorBuilder` in hot paths, `LWatch` for broad page composition.
- **Async scope + sync view:** compose explicitly with `LAsyncScope + LView`.
- **Sync scope + async view:** use `LScopedAsyncView`.

## Middleware Lifecycle

Token-based middleware registration is the default convention:

- Use one stable token per concern.
- Re-register with the same token to replace in place.
- Remove by token on feature teardown.

Reference docs with concrete examples:
- DI middleware lifecycle: [`packages/core/levit_scope/README.md`](./packages/core/levit_scope/README.md)
- Reactive middleware lifecycle: [`packages/core/levit_reactive/README.md`](./packages/core/levit_reactive/README.md)
- Unified `Levit` facade middleware lifecycle: [`packages/core/levit_dart_core/README.md`](./packages/core/levit_dart_core/README.md)

## Documentation Structure

- API semantics live in inline Dartdoc on public APIs.
- Package-level usage guidance lives in each package `README.md`.
- This root README keeps cross-package architecture and adoption guidance.

## Contributing

```bash
melos bootstrap
melos run test
cd benchmarks && flutter run -t lib/main.dart
```

## Examples

Showcase applications live under [`examples/`](./examples):
- [`examples/task_board`](./examples/task_board)
- [`examples/async_catalog`](./examples/async_catalog)
- [`examples/scope_playground`](./examples/scope_playground)
- [`examples/nexus_studio`](./examples/nexus_studio) (advanced reference)

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
