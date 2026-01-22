# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=ooSOnU6nkwg\&flag=levit_dart)](https://codecov.io/github/atoumbre/levit?flags=levit_dart)


**The core composition layer for pure Dart applications. Explicit. Reactive. Deterministic.**

`levit_dart` is the central orchestrator of the Levit ecosystem for non-UI Dart environments. It composes fine-grained reactive primitives from `levit_reactive` and dependency management from `levit_scope` into a professional framework foundation.

---

## Purpose & Scope

`levit_dart` provides a structured, testable model for building business logic without UI dependencies. It is responsible for:
- Orchestrating the relationship between dependency injection and reactive state.
- Defining application-level lifecycle conventions for logic components.
- Providing automated resource management to prevent memory leaks in long-running processes.

It deliberately avoids UI-specific assumptions, making it suitable for servers, CLI tools, and background services. For Flutter-specific integration, use `levit_flutter`.

---

## Conceptual Overview

### Application Elements
- **`LevitController`**: The fundamental unit of logic. It encapsulates state and behavior, participating in a managed lifecycle.
- **Ambient Scoping**: Uses Zone-based propagation to resolve dependencies implicitly, reducing boilerplate while maintaining strict isolation.
- **Auto-Linking**: A mechanism that automatically tracks reactive state created within a controller or registration builder for deterministic cleanup.

---

## Getting Started

### Define a Controller
```dart
class CounterController extends LevitController {
  late final count = autoDispose(0.lx);

  void increment() => count.value++;
}
```

### Usage
```dart
void main() {
  // Register and resolve implicitly
  Levit.put(() => CounterController());
  
  final controller = Levit.find<CounterController>();
  controller.increment();
}
```

---

## Design Principles

### Explicit over Implicit
While `levit_dart` provides ambient scoping for convenience, every dependency and state transition is trackable and deterministic. There are no "magic" global states.

### Composition over Inheritance
The framework encourages composing logic within controllers rather than deep inheritance hierarchies. Lifecycle hooks are designed to be predictable and easy to mock.

### Deterministic Lifecycle
Resources are never left to the garbage collector alone. The `autoDispose` mechanism ensures that streams, timers, and reactive objects are closed as soon as their owning controller is removed from its scope.
