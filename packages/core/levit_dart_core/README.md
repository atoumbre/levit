# levit_dart_core

[![Pub Version](https://img.shields.io/pub/v/levit_dart_core)](https://pub.dev/packages/levit_dart_core)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

The foundational composition layer for the Levit ecosystem. Explicit. Reactive. Deterministic.

`levit_dart_core` orchestrates the relationship between [levit_reactive] primitives and [levit_scope] dependency management into a structured framework for building pure Dart business logic.

---

## Purpose & Scope

`levit_dart_core` provides a predictable environment for managing application logic without UI dependencies. It is responsible for:

- **Lifecycle Orchestration**: Defining how components are initialized, attached to scopes, and disposed.
- **Automated Resource Management**: Ensuring all streams, timers, and reactive objects are cleaned up deterministically.
- **Composition Conventions**: Providing both class-based ([LevitController]) and functional ([LevitState]) abstractions for logic.

It deliberately avoids UI or platform-specific logic, making it suitable for CLI tools, servers, and background services. For Flutter integration, use `levit_flutter_core`.

---

## Conceptual Overview

### Application Elements

- **[LevitController]**: A managed component that encapsulates state and behavior. It participates in an explicit lifecycle and uses `autoDispose` for resource management.
- **[LevitState]**: A functional provider that acts as a factory for state instances, offering a modern alternative to class-based controllers.
- **[Levit]**: The central registry and entry point for managing scopes and resolving dependencies.

### Key Mechanisms

- **Ambient Scoping**: Uses Zone-based propagation via `levit_scope` to resolve dependencies implicitly without manual passing.
- **Auto-Linking**: Automatically tracks reactive state created within a controller or state builder to ensure zero-leak disposal.

---

## Getting Started

### 1. Define a Controller

```dart
class CounterController extends LevitController {
  // Logic is automatically registered for cleanup
  late final count = autoDispose(0.lx);

  void increment() => count.value++;
}
```

### 2. Register and Resolve

```dart
void main() {
  // Register the controller in the current scope
  Levit.put(() => CounterController());
  
  // Resolve and use
  final controller = Levit.find<CounterController>();
  controller.increment();
}
```

---

## Design Principles

### Explicit over Implicit
While [Levit] provides ambient scoping for ergonomics, every state transition and dependency link is trackable and deterministic.

### Managed Lifecycle
Resources are never left to the garbage collector alone. The `onClose` hook and `autoDispose` mechanism ensure that all side effects are terminated as soon as a component is removed.

### Functional Composition
The framework encourages composing logic via [LevitState] to reduce boilerplate and improve encapsulation, while providing [LevitController] for more complex or hierarchical logic.
