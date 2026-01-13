
# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=AESOtS4YPg\&flag=levit_dart)](https://codecov.io/github/atoumbre/levit?flags=levit_dart)

**The core composition layer for pure Dart applications. Explicit. Reactive. Testable.**

`levit_dart` is the **non-UI core framework** of the Levit ecosystem. It composes the reactive primitives from `levit_reactive` and the dependency-management model from `levit_di` into a coherent foundation for building **scalable, deterministic Dart applications**—without any Flutter dependency.

It is designed for shared business logic, servers, background watchers, CLI tools, and any environment where application structure and lifecycle discipline matter.

> **Note**
> For Flutter applications, use [`levit_flutter`](../levit_flutter), which includes this package and integrates it with the widget tree.

---

## What `levit_dart` Provides

Unlike `levit_reactive` and `levit_di`, which are standalone primitives, `levit_dart` defines **application-level conventions**:

* How stateful logic is structured
* How lifecycles are managed
* How reactive state and dependencies interact

It turns low-level building blocks into a practical framework for real applications.

---

## Features

* **`LevController`**
  A base class for business logic components with explicit lifecycle management.

* **Task and Async Coordination**
  Built-in support for structured task execution (idle, running, success, error).

* **Integrated Dependency Injection**
  Re-exports and standardizes usage of `levit_di` for service and controller resolution.

* **Integrated Reactivity**
  Re-exports `levit_reactive` for fine-grained state, computed values, and async state.

* **Pure Dart, No UI Assumptions**
  Designed to run identically on server, client, and test environments.

---

## Installation

```yaml
dependencies:
  levit_dart: ^latest
```

```dart
import 'package:levit_dart/levit_dart.dart';
```

---

## Quick Start

### Define a Controller

```dart
class CounterController extends LevController {
  final count = 0.lx;

  void increment() {
    count.value++;
  }
}
```

A `LevController`:

* Owns reactive state
* Encapsulates business logic
* Participates in deterministic lifecycle management

---

### Register and Use the Controller

```dart
void main() {
  // Register the controller
  Lev.put(CounterController());

  // Resolve it anywhere
  final controller = Lev.find<CounterController>();

  // Observe reactive state
  final disposer = controller.count.listen((value) {
    print('Count is now: $value');
  });

  controller.increment(); // Count is now: 1

  disposer();
}
```

This pattern works identically in:

* Server applications
* Shared libraries
* Unit tests
* Flutter apps (when paired with `levit_flutter`)

---

## Lifecycle Semantics

`LevController` integrates tightly with Levit’s DI and reactive layers:

* `onInit` is called once after construction
* Reactive resources are tracked automatically
* `onDispose` is invoked when the controller or its scope is destroyed

This makes controllers safe, predictable, and easy to test.

---

## When to Use `levit_dart`

Use `levit_dart` when you need:

* A structured way to write application logic in Dart
* Deterministic state and lifecycle handling
* Shared business logic across multiple runtimes

For UI binding and widget-tree scoping, add **`levit_flutter`**.
For lower-level control, you can use **[`levit_reactive`](../levit_reactive)** or **[`levit_di`](../levit_di)** directly.

---

## Design Philosophy

`levit_dart` exists to enforce **discipline without rigidity**:

* Explicit over implicit
* Composition over inheritance
* Determinism over convenience

It provides just enough structure to scale, while remaining flexible enough to adapt to different architectures.

