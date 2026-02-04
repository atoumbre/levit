# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_scope)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_scope` is the pure Dart dependency injection and lifecycle container used across the Levit ecosystem.

It is responsible for:
- Registering dependencies (eager, lazy, and async).
- Resolving dependencies through a parent/child scope hierarchy.
- Disposing dependencies deterministically when a scope is closed.

It intentionally does not provide:
- Reactive state primitives (see `levit_reactive`).
- Flutter widget bindings (see `levit_flutter_core` / `levit_flutter`).

## Conceptual Overview

A `LevitScope` is a container with a local registry and an optional parent scope.
Lookups start in the local registry and may fall back to parent scopes.

`levit_scope` supports two complementary access patterns:
- Explicit scoping by passing a `LevitScope` instance and calling methods on it.
- Implicit scoping through `Ls.currentScope` using a `Zone` context.

## Getting Started

Install:

```yaml
dependencies:
  levit_scope: ^latest
```

Minimal usage:

```dart
import 'package:levit_scope/levit_scope.dart';

class ApiClient {}

void main() {
  final scope = LevitScope.root('root').createScope('feature');

  scope.put(() => ApiClient());
  final client = scope.find<ApiClient>();

  // Optional: make `scope` the implicit `Ls.currentScope` for a call chain.
  scope.run(() {
    final sameClient = Ls.find<ApiClient>();
    assert(identical(client, sameClient));
  });
}
```

## Design Principles

- Explicit lifecycles: objects can participate in deterministic initialization and teardown.
- Hierarchical isolation: child scopes can override dependencies without leaking to parents.
- Reflection-free: registrations and lookups are type-driven and explicit.
