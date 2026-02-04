# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter_core` is the Flutter binding layer for the Levit ecosystem.

It is responsible for:
- Connecting `levit_reactive` dependency tracking to Flutter rebuilds.
- Providing widget-tree-scoped dependency injection with deterministic disposal.
- Bridging widget-tree scoping (InheritedWidget) with Levit's `Zone`-based scoping.

It intentionally does not provide:
- Higher-level app patterns and add-on widgets (see `levit_flutter`).

## Conceptual Overview

`levit_flutter_core` provides low-level widgets that:
- Create and propagate a `LevitScope` through the widget tree (`LScope`).
- Rebuild a widget subtree when the reactive values read during build change (`LWatch`).
- Manage controller-driven views with explicit lifecycles (`LView` / `LScopedView`).

## Getting Started

Install:

```yaml
dependencies:
  levit_flutter_core: ^latest
```

Minimal usage:

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count(count() + 1);
}

class CounterText extends StatelessWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Levit.find<CounterController>();
    return LWatch(() => Text('Count: ${controller.count()}'));
  }
}

void main() {
  runApp(
    MaterialApp(
      home: LScope.put(
        () => CounterController(),
        child: Scaffold(
          body: const Center(child: CounterText()),
          floatingActionButton: Builder(
            builder: (context) {
              final controller = Levit.find<CounterController>();
              return FloatingActionButton(
                onPressed: controller.increment,
                child: const Icon(Icons.add),
              );
            },
          ),
        ),
      ),
    ),
  );
}
```

## Design Principles

- Explicit scoping: UI lifecycles own dependency scopes; disposal happens on unmount.
- Fine-grained rebuilds: only widgets that read a reactive value rebuild when it changes.
- Minimal surface area: higher-level patterns live in `levit_flutter`.
