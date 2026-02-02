# levit_dart_core

[![Pub Version](https://img.shields.io/pub/v/levit_dart_core)](https://pub.dev/packages/levit_dart_core)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart_core)](https://codecov.io/github/atoumbre/levit)

**The logic and state composition layer of the Levit ecosystem.**

`levit_dart_core` bridges the gap between raw reactivity (`levit_reactive`) and dependency injection (`levit_scope`). It provides structured patterns like **Controllers** and **Stores** for building robust, improved business logic.

---

## Why use this?

Raw reactivity is great, but apps need structure. Who owns the state? When is it disposed? How do modules talk to each other?

`levit_dart_core` answers these questions with:

*   **Managed Lifecycles**: Controllers have clear `onInit` and `onClose` hooks.
*   **Auto-Disposal**: Resources (streams, signals) are automatically cleaned up.
*   **Dependency Injection**: A unified API (`Levit.find`, `Levit.put`) for accessing the scope system.
*   **Zero-Boilerplate**: Utilities to link state to owners without manual tracking.

---

## Core Concepts

### 1. LevitController
A class-based container for business logic. It has a full lifecycle and can be registered in the DI system.

```dart
class AuthController extends LevitController {
  // 1. Reactive State
  final user = Rx<User?>(null);
  
  // 2. Lifecycle
  @override
  void onInit() {
    // 3. Auto-Cleanup
    // The subscription will be cancelled automatically when
    // this controller is removed from memory.
    autoDispose(
      authService.userStream.listen((u) => user.value = u)
    );
  }

  void login() => authService.login();
}
```

### 2. LevitStore
A functional, lightweight alternative to controllers. Think of it as a "recipe" for state that can be reused.

```dart
// Define the store
final counterStore = LevitStore((ref) {
  final count = 0.lx;
  return (
    count: count,
    increment: () => count.value++,
  );
});

// Use it anywhere (Lazily created on first access)
final api = counterStore.find();
api.increment();
```

### 3. The `Levit` Entry Point
The unified gateway to all Levit features.

| Method | Description |
|:-------|:------------|
| `Levit.put(() => ...)` | Registers a new dependency. |
| `Levit.find<T>()` | Finds an existing dependency. |
| `Levit.lazyPut(...)` | Registers a lazy builder. |
| `Levit.reset()` | Clears the current scope (useful for testing). |

---

## Auto-Linking

One of the most powerful features of `levit_dart_core` is **Auto-Linking**. When enabled, any reactive value created inside a controller's `onInit` is automatically "owned" by that controller.

```dart
class MyController extends LevitController {
  @override
  void onInit() {
    // This reactive is automatically disposed when MyController closes!
    // No need to manually call .close()
    final name = 'Test'.lx; 
  }
}
```

---

## Installation

This package is usually installed as a transitive dependency of `levit`.

```yaml
dependencies:
  levit: ^latest
```

If you are building a pure Dart app (CLI, Server), you can depend on it directly:

```yaml
dependencies:
  levit_dart_core: ^latest
```
