# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter_core` is the low-level Flutter binding layer for Levit.

This package is responsible for:

- `LScope` / `LAsyncScope`: widget-tree-scoped dependency injection.
- `LWatch`: reactive rebuild boundaries based on accessed values.
- `LView`, `LAsyncView`, `LScopedView`: controller/view orchestration widgets.
- Builder widgets (`LBuilder`, selector/status builders) for focused reactive rendering.

This package does not include:

- Higher-level convenience widgets and runtime helpers provided by `levit_flutter`.

## Conceptual Overview

`levit_flutter_core` bridges two scope models:

- Flutter tree scope via `InheritedWidget`.
- Levit execution scope via `Zone`-based current scope.

The package ensures widget lifecycle events and DI lifecycle events stay synchronized, so registrations created for a subtree are disposed when that subtree unmounts.

## Getting Started

```yaml
dependencies:
  levit_flutter_core: ^latest
```

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count(count() + 1);
}

void main() {
  runApp(
    MaterialApp(
      home: LScope.put(
        () => CounterController(),
        child: Builder(
          builder: (context) {
            final controller = context.levit.find<CounterController>();
            return Scaffold(
              body: Center(
                child: LWatch(() => Text('Count: ${controller.count()}')),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: controller.increment,
                child: const Icon(Icons.add),
              ),
            );
          },
        ),
      ),
    ),
  );
}
```

## Design Principles

- Tree-owned lifecycles: widget mount/unmount controls scope setup/disposal.
- Fine-grained rebuilds: widgets rebuild only for values read during build.
- Explicit composition: sync and async scope/view variants remain explicit.
- Minimal API surface: package stays focused on foundational bindings.

