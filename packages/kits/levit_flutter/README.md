# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**Official Flutter integration for the Levit ecosystem.**

`levit_flutter` provides the necessary glue to connect Levit's high-performance reactive state (`levit_reactive`) and hierarchical dependency injection (`levit_scope`) with the Flutter widget tree.

---

## Purpose & Scope

`levit_flutter` is the primary entry point for Flutter developers. It is responsible for:
- Binding reactive state updates to widget rebuilds with minimal overhead.
- Providing widgets for scope management and dependency propagation.
- Offering lifecycle-aware hooks and widgets for clean resource management in the UI.

---

## Conceptual Overview

### Core Abstractions
- **[LWatch]**: A widget that automatically rebuilds when reactive variables it accesses change.
- **[LView]**: A controlled view that lifecycle-manages its own scoped dependencies.
- **[LScope]**: A widget that injects a [LevitScope] into the subtree.

---

## Getting Started

### Watching State
```dart
final count = 0.lx;

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LWatch(() => Text('Count: ${count.value}'));
  }
}
```

---

## Design Principles

### Precision Rebuilds
Granular reactivity ensures that only the specific widgets reading a piece of state are rebuilt, avoiding full subtree re-renders.

### Intuitive Scoping
Leverages Flutter's `InheritedWidget` patterns to make dependency injection feel natural and integrated with the framework's architecture.
