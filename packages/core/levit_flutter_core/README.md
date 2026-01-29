# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

The Flutter integration layer for the Levit framework. Declarative. Precise. Non-invasive.

`levit_flutter_core` bridges Levit’s pure Dart core into Flutter’s widget tree. It connects the reactivity of [levit_reactive] and the lifecycle discipline of [levit_dart_core] to Flutter while strictly adhering to Flutter's architectural principles.

---

## Purpose & Scope

`levit_flutter_core` provides the necessary glue to project Levit's application logic into your UI. It is responsible for:

- **Reactive UI Binding**: Mapping reactive state transitions to fine-grained widget rebuilds via [LWatch].
- **Widget-Bound Scoping**: Providing dependency injection scopes that are lifecycle-bound to the widget tree via [LScope].
- **View-Level Abstractions**: Standardizing view-level logic through managed base classes like [LView] and [LScopedView].

It is designed as an additive layer that complements Flutter's native widgets rather than replacing them.

---

## Conceptual Overview

### Core Elements

- **[LWatch]**: The primary observer widget. It automatically rebuilds the widget tree whenever reactive variables accessed in its builder change.
- **[LScope]**: A widget that defines an isolated dependency injection scope. It ensures that services and controllers are created and disposed exactly when needed.
- **[LView]**: A base class for UI components that offers automatic controller resolution and reactive tracking with minimal boilerplate.
- **[LWatchStatus]**: A declarative builder for handling asynchronous state transitions (Waiting, Success, Error) with high performance.

---

## Getting Started

### 1. Simple Reactivity with `LWatch`

```dart
final count = 0.lx;

LWatch(() => Text('Value: ${count.value}'))
```

### 2. Dependency Scoping

```dart
LScope(
  dependencyFactory: (scope) => scope.put(() => MyController()),
  child: const MyPage(),
)
```

---

## Design Principles

### Non-Invasive Reactivity
`levit_flutter_core` localized updates to the specific widgets that consume state. It does not require global providers or broad rebuilds of the entire widget tree.

### Explicit Lifecycle Wiring
Lifecycle hooks for business logic are deterministic and tied directly to the mounting and unmounting of the widgets that own them.

### Tree-Based Resolution
Dependency resolution follows a predictable tree-search pattern, ensuring that components always resolve the most relevant instance of a service or controller from their current context.
