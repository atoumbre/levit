# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**Type-safe, hierarchical dependency injection for Dart. Explicit. Scoped. Deterministic.**

`levit_scope` provides a robust, reflection-free dependency injection mechanism designed for applications requiring predictable lifecycles and explicit scoping. It serves as the core container engine for the Levit framework.

---

## Purpose & Scope

`levit_scope` manages the lifecycle and resolution of dependencies. It is responsible for:
- Enforcing hierarchical isolation between different layers of an application.
- Orchestrating lifecycle hooks (`onInit`, `onClose`) for managed components.
- Providing a pure Dart, side-effect-free container that works across all platforms.

---

## Conceptual Overview

### Core Abstractions
- **[LevitScope]**: A container that holds dependency registrations. Scopes form a tree where children can inherit or override parent dependencies.
- **[LevitScopeDisposable]**: An interface that components implement to participate in the container's lifecycle.
- **Ambient Scoping**: Automatic detection of the active scope using [Zone]-based propagation, accessible via the [Ls] static interface.

---

## Getting Started

### Hierarchical Scoping
```dart
// Create a root scope
final root = LevitScope.root();

// Register a singleton
root.put(() => AuthService());

// Create a nested scope
final featureScope = root.createScope('feature');
featureScope.put(() => FeatureService());

// Resolve (falls back to parent if not found locally)
final auth = featureScope.find<AuthService>();
```

### Lifecycle Hooks
```dart
class Database implements LevitScopeDisposable {
  @override
  void onInit() => print('Connecting...');

  @override
  void onClose() => print('Closing connection...');
}
```

---

## Design Principles

### Explicitness over Magic
No reflection or code generation. Every dependency is registered via typed builders, ensuring full type safety and transparency.

### Deterministic Teardown
Disposing a scope guarantees that every owned dependency implementing [LevitScopeDisposable] has its `onClose` method called, preventing resource leaks.

### Hierarchical Isolation
Scopes provide a strict hierarchy. This allows for powerful mocking and feature-specific resource allocation without global state pollution.
