# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=ooSOnU6nkwg\&flag=levit_flutter)](https://codecov.io/github/atoumbre/levit?flags=levit_flutter)


**The Flutter integration layer for the Levit framework. Declarative. Precise. Non-invasive.**

`levit_flutter` bridges Levit’s pure Dart core into Flutter’s widget tree. It connects the reactivity of `levit_reactive` and the lifecycle discipline of `levit_dart` to Flutter while strictly adhering to Flutter's architectural principles.

---

## Purpose & Scope

`levit_flutter` provides the necessary glue to project Levit's application logic into your UI. It is responsible for:
- Mapping reactive state transitions to fine-grained widget rebuilds.
- Providing widget-bound dependency injection scopes.
- Standardizing view-level lifecycle logic through managed base classes.

It is designed to be an additive integration layer, meaning it complements Flutter's native widgets rather than replacing them.

---

## Conceptual Overview

### Core Elements
- **`LWatch`**: An observer widget that automatically rebuilds when any reactive variable accessed in its build method changes.
- **`LScope`**: A widget that defines an isolated dependency injection scope bound to its position in the widget tree.
- **`LView`**: A base class for UI components that provides automatic controller resolution and reactive tracking.
- **`LStatusBuilder`**: A declarative builder for handling asynchronous state transitions (Waiting, Success, Error).

---

## Getting Started

### Reactive UI with `LWatch`
```dart
final count = 0.lx;

LWatch(() => Text('Value: ${count.value}'))
```

### Dependency Scoping
```dart
LScope(
  init: () => MyController(),
  child: const MyPage(),
)
```

### Context-based Resolution
```dart
final controller = context.levit.find<MyController>();
```

---

## Design Principles

### Non-Invasive Reactivity
Unlike many state management solutions, `levit_flutter` does not require global providers or broad rebuilds. Reactivity is localized to the specific widgets that consume the state.

### Explicit Lifecycle Wiring
Controller lifecycles (`onInit`, `onClose`) are deterministic and tied directly to the mounting and unmounting of the widgets that own them.

### Determinism
Dependency resolution follows a predictable tree-search pattern, ensuring that components always resolve the most relevant instance of a service or controller.
