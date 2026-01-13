
# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=AESOtS4YPg\&flag=levit_reactive)](https://codecov.io/github/atoumbre/levit?flags=levit_reactive)

**A pure Dart reactive engine. Deterministic. Fine-grained. Dependency-free.**

`levit_reactive` is the **foundational reactivity layer** of the Levit ecosystem. It provides a high-performance, zero-boilerplate way to model state, derived values, and asynchronous data flows in **any Dart environment**—including servers, CLI tools, tests, and Flutter applications.

It is intentionally framework-agnostic and can be used as a standalone reactive library or as part of the broader Levit stack.

> **Note**
> For Flutter applications, use [`levit_flutter`](../levit_flutter), which includes this package and integrates it with the widget tree.

---

## Features

* **Zero Boilerplate Reactivity**
  Any value becomes reactive via `.lx`, with no annotations or code generation.

* **Fine-Grained Dependency Tracking**
  Only the exact dependencies accessed during evaluation are tracked and recomputed.

* **First-Class Async State**
  Futures and Streams are modeled as reactive state via `LxStatus` (Idle, Waiting, Success, Error).

* **Deterministic Computed Values**
  Computeds are lazy, cached, and recompute only when their dependencies change.

* **Middleware and Interception**
  Intercept and observe state changes globally for logging, persistence, undo/redo, or analytics.

* **Pure Dart, Zero Dependencies**
  No Flutter imports. No platform assumptions. Runs anywhere Dart runs.

---

## Installation

```yaml
dependencies:
  levit_reactive: ^latest
```

```dart
import 'package:levit_reactive/levit_reactive.dart';
```

---

## Quick Start

### Basic Reactivity

```dart
// Create reactive state
final count = 0.lx;

// Subscribe to changes
count.addListener(() {
  print('Count changed to: ${count.value}');
});

// Mutate state
count.value++; // Count changed to: 1
```

Reactive values notify listeners synchronously and deterministically.

---

### Computed Values

Computed values automatically track only the reactive values they read. They are **lazy** (evaluated on first access) and **cached** (re-evaluated only when dependencies change).

```dart
final firstName = 'John'.lx;
final lastName = 'Doe'.lx;

final fullName = LxComputed(() => '${firstName.value} ${lastName.value}');

print(fullName.value); // John Doe

firstName.value = 'Jane';
print(fullName.value); // Jane Doe
```

---

## Async State Handling

`levit_reactive` eliminates the need for ad-hoc `isLoading`, `hasError`, or `errorMessage` flags by modeling async state explicitly.

### Futures

```dart
final userState = LxFuture(fetchUserById(123));

switch (userState.status) {
  case LxWaiting():
    print('Loading...');
  case LxSuccess(:final value):
    print('User loaded: ${value.name}');
  case LxError(:final error):
    print('Failed: $error');
  case LxIdle():
    print('Not started');
}

// Trigger a refresh
userState.refresh(fetchUserById(456));
```

Async state is always available synchronously.

---

### Streams

```dart
final messages = LxStream(channel.stream);

// Access the latest value at any time
print(messages.valueOrNull);
```

Stream lifecycles are managed automatically.

---

## Middleware

Middleware provides a global interception mechanism for all state changes. This enables cross-cutting concerns without polluting domain logic.

```dart
Lx.middlewares.add(
  LxLoggerMiddleware(
    formatter: (change) =>
        '[${DateTime.now()}] ${change.name}: '
        '${change.oldValue} -> ${change.newValue}',
  ),
);

final counter = 0.lxNamed('Counter');
counter.value++;
```

Typical use cases include:

* Logging and diagnostics
* Persistence and synchronization
* Time-travel debugging and undo/redo

---

## Performance Characteristics

`levit_reactive` is designed to scale under heavy mutation and high-frequency updates.

* **O(1) Listener Notification**
  Uses a specialized notifier rather than Streams for synchronous updates.

* **Atomic Batch Updates**
  Group multiple mutations into a single notification cycle.

```dart
Lx.batch(() {
  firstName.value = 'Bob';
  age.value = 42;
});
```

This ensures predictable performance even with large reactive graphs.

---

## When to Use `levit_reactive`

Use `levit_reactive` directly when you need:

* A lightweight reactive engine without UI coupling
* Deterministic, testable state derivation
* Shared logic across client, server, and tools

For Flutter UI binding and lifecycle integration, pair it with **[`levit_flutter`](../levit_flutter)**.

