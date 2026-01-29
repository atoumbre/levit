# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**A pure Dart reactive engine. Deterministic. Fine-grained. Dependency-free.**

`levit_reactive` is the foundational reactivity layer of the Levit ecosystem. It provides a high-performance, zero-boilerplate way to model state, derived values, and asynchronous data flows in any Dart environment.

---

## Purpose & Scope

`levit_reactive` manages reactive state and its derivation graph. It is responsible for:
- Providing zero-boilerplate reactivity via extension methods.
- Managing fine-grained dependency tracking for synchronous and asynchronous computations.
- Modeling asynchronous operations as type-safe status transitions.
- Offering a global interception mechanism via middlewares.

---

## Conceptual Overview

### Core Abstractions
- **[LxReactive]**: The base interface for all reactive sources.
- **[LxComputed]**: Derived state that automatically tracks and memoizes dependencies.
- **[LxStatus]**: A sealed hierarchy representing the lifecycle of an async operation (Idle, Waiting, Success, Error).
- **[Lx]**: The primary static entry point for configuration, batching, and tracking.

---

## Getting Started

### Basic Reactivity
```dart
// Create reactive state
final count = 0.lx;

// Listen to changes
count.addListener(() => print('Count: ${count.value}'));

// Mutate
count.value++;
```

### Computed Values
```dart
final firstName = 'John'.lx;
final lastName = 'Doe'.lx;
final fullName = LxComputed(() => '${firstName.value} ${lastName.value}');

print(fullName.value); // John Doe
```

### Async State
```dart
final user = LxAsyncComputed(() => fetchUser(123));

if (user.isWaiting) {
  print('Loading...');
}
```

---

## Design Principles

### Transparent Reactivity
Reactivity is achieved by simply reading values. No manual subscription management, annotations, or code generation required.

### Determinism
Notifications are synchronous and topologically sorted. This ensures that a single state change never results in inconsistent derived values or redundant updates.

### Pure Dart
The core engine has zero dependencies and no platform-specific requirements, making it suitable for everything from backend services to complex UIs.
