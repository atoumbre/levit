# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**A pure Dart reactive engine. Deterministic. Fine-grained. Dependency-free.**

`levit_reactive` is the foundational reactivity layer of the Levit ecosystem. It provides a high-performance, zero-boilerplate way to model state, derived values, and asynchronous data flows in any Dart environment.

---

## Purpose & Scope

`levit_reactive` manages reactive state and its derivation graph. It is responsible for:

- **Zero-Boilerplate Reactivity**: Create reactive state via simple `.lx` extensions.
- **Automatic Dependency Tracking**: Computed values track their sources automatically.
- **Async Status Modeling**: Type-safe `LxStatus` hierarchy for async operation states.
- **Reactive Collections**: `LxList`, `LxMap`, and `LxSet` for collection-level reactivity.
- **Middleware Interception**: Global hooks for logging, undo/redo, and diagnostics.

---

## Core Abstractions

| Type | Description |
|:-----|:------------|
| `LxReactive<T>` | Base interface for all reactive objects |
| `LxVar<T>` | Mutable reactive variable |
| `LxComputed<T>` | Derived state with automatic dependency tracking |
| `LxAsyncComputed<T>` | Async derived state returning `LxStatus<T>` |
| `LxStatus<T>` | Sealed hierarchy: `LxIdle`, `LxWaiting`, `LxSuccess`, `LxError` |
| `LxList<E>`, `LxMap<K,V>`, `LxSet<E>` | Reactive collections |
| `LxWorker<T>` | Side-effect observer with monitoring |
| `Lx` | Static entry point for batching and configuration |

---

## Getting Started

### Basic Reactivity
```dart
final count = 0.lx;
count.addListener(() => print('Count: ${count.value}'));
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

### Batching
```dart
Lx.batch(() {
  count.value = 1;
  name.value = 'Updated';
}); // Single notification
```

---

## Design Principles

### Transparent Reactivity
Reactivity is achieved by simply reading values. No manual subscription management, annotations, or code generation required.

### Determinism
Notifications are synchronous and topologically sorted. A single state change never results in inconsistent derived values or redundant updates.

### Pure Dart
Zero dependencies and no platform-specific requirements, making it suitable for backend services, CLI tools, and complex UIs.

