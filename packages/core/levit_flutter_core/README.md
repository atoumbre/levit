# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter_core` owns the Flutter binding layer for Levit.

Use this package directly when you want Flutter bindings without the higher-level `levit_flutter` kit.

This package is responsible for:

- `LScope` / `LAsyncScope`: widget-tree-scoped dependency injection.
- `LWatch`: reactive rebuild boundaries based on accessed values.
- `LView`, `LAsyncView`, `LScopedView`: controller/view orchestration widgets.
- Builder widgets (`LBuilder`, selector/status builders) for focused reactive rendering.

This package also re-exports `levit_dart_core` for convenience, so `Levit`, `LevitController`, stores, and reactive primitives remain available from one import.

This package does not include:

- Higher-level convenience widgets and runtime helpers provided by `levit_flutter`.
- New Dart runtime semantics beyond what `levit_dart_core` already defines.

## Conceptual Overview

`levit_flutter_core` bridges two scope models:

- Flutter tree scope via `InheritedWidget`.
- Levit execution scope via `Zone`-based current scope.

The package ensures widget lifecycle events and DI lifecycle events stay synchronized, so registrations created for a subtree are disposed when that subtree unmounts.

## Choosing the Right Widget

| API | Use when | Prefer another API when |
| :-- | :-- | :-- |
| `LWatch` | A small subtree should rebuild for whichever reactive values it reads during build. | The dependency is already explicit and singular; prefer `LBuilder`. |
| `LBuilder` | You already know the exact `LxReactive` to observe. | The subtree depends on several reactive reads discovered during build; prefer `LWatch`. |
| `LSelectorBuilder` | You want a small derived value local to one subtree without promoting it to controller state. | The derived value is shared across widgets or long-lived; move it into a controller/store computed. |
| `LStatusBuilder` | You are rendering an `LxStatus<T>` with waiting, error, and success branches. | You are not working with `LxStatus`; prefer `LBuilder` or `LWatch`. |
| `LView` | The controller/service already exists in the nearest scope and you only need to render it. | The widget should create and own a child scope; prefer `LScopedView`. |
| `LAsyncView` | The dependency resolves asynchronously from the current scope. | You also need to create a new scope boundary or async scope initialization; prefer `LScopedAsyncView` or `LAsyncScope`. |
| `LScopedView` | One widget should create a child scope, register a dependency, and render it. | The scope already exists; prefer `LView`. |
| `LScopedAsyncView` | One widget should create a child scope and resolve the dependency asynchronously. | You only need an async scope boundary without the view abstraction; prefer `LAsyncScope`. |
| `LScope` / `LAsyncScope` | You need a scope boundary for a subtree, independent of a specific controller/view widget. | A single controller-view pair is enough; prefer `LScopedView` or `LScopedAsyncView`. |

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
- Focused ownership: package owns Flutter bindings and re-exports the Dart core layer for convenience.
