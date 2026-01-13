
# levit_di

[![Pub Version](https://img.shields.io/pub/v/levit_di)](https://pub.dev/packages/levit_di)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_di)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=AESOtS4YPg\&flag=levit_di)](https://codecov.io/github/atoumbre/levit?flags=levit_di)

**Type-safe, hierarchical dependency injection for Dart. Explicit. Scoped. Deterministic.**

`levit_di` is a **pure Dart dependency injection and service registry** designed for applications that require **predictable lifecycles, explicit scoping, and type safety**. It provides a minimal but powerful set of primitives for managing services and controllers across both UI and non-UI Dart environments.

It is framework-agnostic by design and can be used standalone, or as the dependency backbone of the broader Levit ecosystem.

> **Note**
> For Flutter applications, use [`levit_flutter`](../levit_flutter), which includes this package and integrates it with the widget tree.

---

## Features

* **Simple, Explicit API**
  Register with `Levit.put`, retrieve with `Levit.find`. No annotations or code generation.

* **Lazy Initialization**
  `Levit.lazyPut` defers instantiation until the dependency is first requested.

* **Async-First Registration**
  `Levit.putAsync` guarantees that asynchronous dependencies are fully initialized before use.

* **Hierarchical Scoping**
  Create isolated dependency graphs using named or anonymous scopes.

* **Deterministic Lifecycle Management**
  Automatic invocation of `onInit` and `onDispose` hooks for managed services.

* **Pure Dart, Zero UI Coupling**
  Usable in servers, CLI tools, tests, and shared libraries.

---

## Installation

```yaml
dependencies:
  levit_di: ^latest
```

```dart
import 'package:levit_di/levit_di.dart';
```

---

## Quick Start

### Registering Dependencies

```dart
// Eager registration
Levit.put(AuthService());

// Lazy registration (factory)
// The instance is created only when first requested.
Levit.lazyPut(() => Database());

// Async registration
// Calls are suspended until the Future completes.
await Levit.putAsync(() => ConfigService.load());
```

---

### Retrieving Dependencies

```dart
// Available anywhere in your Dart code
final auth = Levit.find<AuthService>();

auth.login();
```

Dependency resolution is synchronous once registration has completed.

---

## Scoped Dependency Graphs

Levit supports **hierarchical scopes**, allowing you to model feature- or lifecycle-bound dependencies explicitly.

```dart
// Create an isolated child scope
final checkoutScope = Levit.createScope('checkout');

// Register dependencies within this scope only
checkoutScope.put(PaymentProcessor());

// Resolve from the same scope
final processor = checkoutScope.find<PaymentProcessor>();

// Dispose the scope and all contained dependencies
checkoutScope.dispose();
```

Scopes enable clear ownership and predictable teardown of resources.

---

## Lifecycle Management

Services can opt into lifecycle hooks by implementing `LevitScopeDisposable`.

```dart
class MyService implements LevitScopeDisposable {
  @override
  void onInit() {
    print('Service initialized');
  }

  @override
  void onDispose() {
    print('Service releasing resources');
  }
}
```

The container guarantees that:

* `onInit` is called exactly once after creation
* `onDispose` is called when the service is removed or its scope is destroyed

This makes resource management explicit and testable.

---

## When to Use `levit_di`

Use `levit_di` directly when you need:

* A lightweight, type-safe service locator
* Explicit lifecycle and scope control
* Dependency management outside of Flutter

For reactive state and derived values, pair it with **[`levit_reactive`](../levit_reactive)**.
For Flutter widget integration, add **[`levit_flutter`](../levit_flutter)**.

---

## Design Philosophy

`levit_di` favors:

* Explicitness over hidden behavior
* Deterministic lifecycles over global singletons
* Composability over framework lock-in

It provides the minimum surface area required to manage dependencies correctly—no more, no less.

