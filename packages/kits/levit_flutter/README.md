# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter` is the recommended entry point for using the Levit ecosystem in Flutter applications.

It is responsible for:
- Providing Flutter widget bindings for reactive state and scopes.
- Providing controller-centric view patterns for UI composition.
- Including pure Dart controller utilities (`levit_dart`) and app-specific Flutter helpers.

It intentionally does not provide:
- Non-Flutter platform integrations (use `levit` for pure Dart).

## Conceptual Overview

`levit_flutter` composes:
- `levit_flutter_core` for widget bindings (`LScope`, `LWatch`, and view widgets).
- `levit_dart` for controller utilities (tasks, loops).
- Additional Flutter-specific mixins and widgets that tie controller lifecycles to the Flutter runtime.

## Getting Started

Install:

```yaml
dependencies:
  levit_flutter: ^latest
```

Minimal usage:

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

## Design Principles

- Widget ownership: scopes and controller lifecycles are tied to widget lifecycles.
- Fine-grained rebuilds: `LWatch` rebuilds only when the reactive values read during build change.
- Composition: higher-level patterns are implemented as widgets and mixins on top of core primitives.
