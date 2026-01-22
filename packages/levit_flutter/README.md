
# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=AESOtS4YPg\&flag=levit_flutter)](https://codecov.io/github/atoumbre/levit?flags=levit_flutter)

**The Flutter integration layer for the Levit framework. Declarative. Precise. Non-invasive.**

`levit_flutter` bridges Levit’s **pure Dart core** into Flutter’s widget tree. It connects the reactivity of `levit_reactive` and the lifecycle discipline of `levit_dart` to Flutter **without altering Flutter’s mental model**.

This package does not replace Flutter concepts—it composes with them.

---

## What `levit_flutter` Is (and Is Not)

`levit_flutter` is a **binding layer**, not a framework rewrite.

* It does **not** introduce a new widget paradigm
* It does **not** hide Flutter primitives
* It does **not** impose global rebuilds or magic observers

Instead, it provides **explicit widgets and extensions** that let Flutter opt into Levit’s reactivity and dependency scoping where it makes sense.

---

## Features

* **`LWatch`**
  A fine-grained reactive widget. Rebuilds *only* when accessed `Lx` values change.

* **`LevitController`**
  A Flutter-aware controller with automatic lifecycle wiring (`onInit`, `onDispose`).

* **`LStatusBuilder`**
  Declarative rendering for async state (waiting, error, success) driven by reactive sources.

* **`LScope`**
  Widget-tree–scoped dependency injection with deterministic teardown.

* **Context Extensions**
  Ergonomic, type-safe access to Levit DI from `BuildContext`.

---

## Installation

```yaml
dependencies:
  levit_flutter: ^latest
```

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
```

---

## Quick Start

### Reactive UI with `LWatch`

`LWatch` automatically tracks any `Lx` value accessed during build and rebuilds only when those values change.

```dart
final count = 0.lx;

LWatch(() => Text(
  'Count: ${count.value}',
  style: const TextStyle(fontSize: 24),
));
```

There are no manual listeners, no disposers, and no global rebuilds.

---

### Controller-Driven State with `LevitController`

Move logic out of widgets while keeping lifecycle guarantees.

```dart
class CounterController extends LevitController {
  late final count = autoDispose(0.lx);

  void increment() {
    count.value++;
  }
}
```

`autoDispose` ensures all reactive resources are released when the controller leaves scope.

---

### Declarative Async UI with `LStatusBuilder`

Render async state without boilerplate or imperative checks.

```dart
class UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<UserController>();

    return LStatusBuilder(
      source: controller.userFuture,
      onWaiting: () => const CircularProgressIndicator(),
      onError: (error, _) => Text('Error: $error'),
      onSuccess: (user) => Text('Hello, ${user.name}'),
    );
  }
}
```

`LStatusBuilder` works with `LxFuture` and `LxStream` from `levit_reactive`.

---

## Dependency Injection & Widget Scoping

Use `LScope` to bind controllers and services to a widget subtree.

```dart
LScope(
  init: () => ProfileController(),
  child: const ProfileView(),
);
```

Inside the subtree:

```dart
final controller = context.levit.find<ProfileController>();
```

When `LScope` is removed:

* `ProfileController.onDispose()` is called
* All tracked reactive resources are released
* No global state leaks occur

---

## Architectural Role

In the Levit stack:

* [`levit_reactive`](../levit_reactive) defines **reactive primitives**
* [`levit_scope`](../levit_scope) defines **dependency scoping**
* [`levit_dart`](../levit_dart) defines **application structure**
* `levit_flutter` projects all of the above into **Flutter’s widget tree**

Each layer remains usable independently.

---

## Design Principles

* **Flutter-first mental model**
* **Explicit rebuild boundaries**
* **Deterministic lifecycles**
* **Zero hidden global observers**

`levit_flutter` exists to let Flutter applications scale in complexity **without scaling rebuild cost or cognitive load**.

