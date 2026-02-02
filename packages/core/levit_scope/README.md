# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_scope)](https://codecov.io/github/atoumbre/levit)

**Type-safe, hierarchical dependency injection for Dart.**

`levit_scope` provides a robust, reflection-free dependency injection mechanism designed for applications requiring predictable lifecycles and explicit scoping. It serves as the core container engine for the Levit ecosystem.

---

## Purpose & Scope

`levit_scope` manages the lifecycle and resolution of dependencies. It is responsible for:
- **Hierarchical Isolation**: creating isolated scopes for features or route branches.
- **Deterministic Lifecycle**: orchestrating initialization (`onInit`) and teardown (`onClose`) hooks.
- **Pure Dart**: working across all platforms without Flutter dependencies or code generation.

---

## Conceptual Overview

### Core Abstractions
- **[LevitScope]**: A container that holds dependency registrations. Scopes form a tree where children can inherit or override parent dependencies.
- **[Ls] (Levit Scope)**: The global static accessor. It uses [Zone]-based context to implicitly detect the active scope.
- **[LevitScopeDisposable]**: An interface that components implement to receive lifecycle callbacks from the container.

### Lifecycle Management
Dependencies are managed deterministically. When a scope is disposed, all dependencies registered within it that implement `LevitScopeDisposable` are automatically closed.

---

## Getting Started

### 1. Basic Registration & Resolution
Use `Ls.put` to register dependencies immediately, and `Ls.find` to retrieve them.

```dart
// Register immediately
Ls.put(() => AuthService());

// Retrieve anywhere in the same scope context
final auth = Ls.find<AuthService>();
```

### 2. Lazy & Async Registration
Use `lazyPut` for dependencies that should only be created when first requested.

```dart
// Created on first use
Ls.lazyPut(() => DatabaseService());

// Async factory (returns Future)
Ls.lazyPutAsync(() => loadConfig());
```

### 3. Hierarchical Scoping
Scopes can be nested. Child scopes can access parent dependencies, but parents cannot see children.

```dart
final root = LevitScope.root();
root.put(() => GlobalService());

final child = root.createScope('feature');
child.put(() => FeatureService());

// Valid: Child sees parent
child.find<GlobalService>(); 

// Invalid: Parent cannot see child
// root.find<FeatureService>(); // Throws Exception
```

### 4. Lifecycle Hooks
Implement `LevitScopeDisposable` to react to initialization and disposal.

```dart
class MyController implements LevitScopeDisposable {
  @override
  void onInit() {
    print('Controller initialized');
  }

  @override
  void onClose() {
    print('Controller disposed');
  }
}
```

---

## Design Principles

### Explicitness over Magic
No reflection or code generation. Every dependency is registered via typed builders, ensuring full type safety and transparency.

### Deterministic Teardown
Disposing a scope guarantees that every owned dependency is properly closed. This prevents memory leaks and ensures resource cleanup (e.g., closing streams, cancelling timers).

### Middleware Support
`levit_scope` supports global middleware for logging or profiling dependency events. Implement `LevitScopeMiddleware` to intercept creation, resolution, and disposal events.
