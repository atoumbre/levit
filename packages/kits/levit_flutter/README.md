# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Purpose & Scope

`levit_flutter` is the recommended single import for Flutter applications using Levit.

This kit composes:

- `levit_flutter_core` widget bindings.
- `levit_dart` controller utility layer.
- Flutter-specific mixins/widgets in this package.

This package is responsible for ergonomic adoption, not replacing core behavior.

## Conceptual Overview

`levit_flutter` keeps runtime semantics in core packages and adds practical Flutter integrations:

- Lifecycle-aware controller mixins that react to app lifecycle.
- Utility widgets for subtree lifecycle monitoring and keep-alive behavior.
- Unified import surface for common Flutter usage.

## Getting Started

```yaml
dependencies:
  levit_flutter: ^latest
```

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
```

## Design Principles

- Widget-tree ownership for scopes and controller lifecycles.
- Fine-grained rebuild behavior inherited from reactive core bindings.
- Composition-first kit design with explicit package boundaries.

