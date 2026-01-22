# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=ooSOnU6nkwg\&flag=levit_scope)](https://codecov.io/github/atoumbre/levit?flags=levit_scope)

**Type-safe, hierarchical dependency injection for Dart. Explicit. Scoped. Deterministic.**

`levit_scope` is a pure Dart dependency injection and service locator designed for applications requiring predictable lifecycles and explicit scoping. It provides a robust, reflection-free mechanism for managing services and controllers across the Levit ecosystem.

---

## Purpose & Scope

`levit_scope` provides the container infrastructure for the Levit framework. Its primary responsibilities include:
- Managing a registry of typed dependencies with optional tagging.
- Enforcing hierarchical isolation between different layers of the application.
- Orchestrating lifecycle hooks (`onInit`, `onClose`) for managed components.

By maintaining a pure Dart profile, it ensures that your dependency graph remains testable and portable across CLI, server, and multi-platform environments.

---

## Conceptual Overview

### Core Abstractions
- **`LevitScope`**: A container that holds dependency registrations. Scopes can be nested to form a tree.
- **`LevitScopeDisposable`**: An interface that allows components to react to their own initialization and disposal.
- **Ambient Scoping**: While `levit_scope` is the low-level engine, it is often used via the ambient `Levit` interface in `levit_dart` for boilerplate-free resolution.

---

## Getting Started

### Hierarchical Scoping
```dart
// Create a root scope
final root = LevitScope.root();

// Register a singleton
root.put(() => AuthService());

// Create a child scope for a specific feature
final featureScope = root.createScope('payment_flow');
featureScope.put(() => PaymentProcessor());

// Resolve from child (falls back to parent)
final auth = featureScope.find<AuthService>();
```

### Lifecycle Hooks
Implement `LevitScopeDisposable` to manage resources:
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
There is no hidden reflection or code generation. Every dependency is registered and resolved via typed builder functions.

### Deterministic Teardown
When a scope is disposed, every disposable dependency it owns is guaranteed to have its `onClose` method called. This is critical for preventing memory leaks in complex applications.

### Isolation
Child scopes can override parent dependencies locally. This enables powerful testing patterns where you can "mock" a dependency for a specific subtree of your application without affecting the global state.
