# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**Utility mixins and tools for Levit Dart controllers.**

`levit_dart` provides high-level abstractions and utility mixins that simplify the implementation of business logic and domain services within the Levit ecosystem. It builds upon `levit_dart_core` to offer production-ready patterns for task execution, paging, and lifecycle management.

---

## Purpose & Scope

`levit_dart` focuses on developer ergonomics for non-UI code. It is responsible for:
- Providing structured wrappers for common patterns like isolate-based tasks.
- Offering mixins for managing complex states like pagination and loading flags.
- Serving as a dependency-injection friendly base for domain controllers.

---

## Conceptual Overview

### Core Abstractions
- **LevitTaskMixin**: A mixin that adds busy-tracking and error handling to unit of work.
- **Isolate Support**: Tools for offloading heavy computations to background isolates with automatic state synchronization.
- **Paging Primitives**: Standardized ways to handle cursors and offsets in data-fetching services.

---

## Getting Started

### Using Task Mixins
```dart
class MyService with LevitTaskMixin {
  Future<void> loadData() async {
    await runTask(() async {
      // Your heavy work here
    });
  }
}
```

---

## Design Principles

### Ergonomics First
Designed to reduce boilerplate in everyday coding tasks without sacrificing the explicitness and type-safety of the underlying core packages.

### Composition over Inheritance
Mixins are preferred for adding functionality to services, allowing for flexible and modular service design.
