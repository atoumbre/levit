# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_reactive)](https://codecov.io/github/atoumbre/levit)

**A high-performance, fine-grained reactive engine for Dart.**

`levit_reactive` powers the state management capabilities of the Levit ecosystem. It provides a modern, signal-based reactivity system that is transparent, glitch-free, and dependency-free.

---

## The Core Concept

At the heart of `levit_reactive` are **Signals** (`LxVar`) and **Effects** (`LxWorker` / `LxComputed`). The system automatically tracks dependencies by simply *reading* values, eliminating the need for manual subscriptions or code generation.

### Quick Example

```dart
// 1. Create reactive state
final count = 0.lx;

// 2. Derive state (updates automatically)
final doubleCount = LxComputed(() => count() * 2);

// 3. React to changes
LxWorker(count, (val) => print('Count changed to: $val'));

// 4. Update
count.value++; // Prints: "Count changed to: 1"
```

---

## Key Features

### 1. Fine-Grained Reactivity
Updates are surgically precise. If a computed value depends on `A` and `B`, unrelated changes to `C` will never trigger a re-computation.

### 2. Glitch-Free by Design
The engine uses **topological sorting** to ensure derived state is always consistent. You will never see a "stale" or "intermediate" value during a complex update chain.

### 3. Async State Management
First-class support for asynchronous flows with `LxStatus`.

```dart
final userId = 1.lx;

// Automatically re-fetches when userId changes
final user = LxAsyncComputed(() => api.fetchUser(userId()));

// Type-safe status usage
switch (user.value) {
  case LxWaiting(): print('Loading...');
  case LxSuccess(value: final u): print('Hello ${u.name}');
  case LxError(error: final e): print('Error: $e');
  case LxIdle(): print('Ready');
}
```

### 4. Reactive Collections
Modifying `LxList`, `LxMap`, or `LxSet` automatically notifies observers.

```dart
final todos = <String>[].lx;
todos.add('Buy milk'); // Triggers UI update
```

### 5. Middleware & Tooling
Built-in hooks for logging, time-travel debugging (undo/redo), and performance profiling.

---

## Detailed API

### Reactive Primitives

| Type | Description |
|:-----|:------------|
| `LxVar<T>` | A mutable reactive variable (Signal). Created via `.lx` extension. |
| `LxComputed<T>` | A derived readonly value. Lazily evaluated and memoized. |
| `LxAsyncComputed<T>` | Derived state from a `Future`. Returns `LxStatus<T>`. |
| `LxWorker<T>` | A side-effect runner (watcher). Captures metrics. |

### Utilities

| Method | Description |
|:-------|:------------|
| `Lx.batch(() => ...)` | Groups multiple updates into a single notification cycle. |
| `Lx.untracked(() => ...)` | Reads reactive values without creating a dependency. |

---

## Integration

While `levit_reactive` is pure Dart and framework-agnostic, it is designed to pair perfectly with **Levit Flutter Core**.

*   **State Management**: Use `Lx` types inside your Controllers.
*   **UI Binding**: Use `LWatch` or `Obx` (in Flutter) to bind signals to widgets.

```dart
// In a Flutter Widget
LWatch((context) {
  return Text('Count: ${controller.count()}');
});
```
