# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_scope)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_scope` is Levit's pure Dart dependency injection and lifecycle runtime.

This package is responsible for:

- Dependency registration (`put`, `lazyPut`, `lazyPutAsync`).
- Hierarchical resolution across parent/child scopes.
- Deterministic cleanup through explicit scope disposal.
- DI middleware interception for cross-cutting concerns.

This package does not include:

- Reactive state primitives (`levit_reactive`).
- Flutter tree integration (`levit_flutter_core`, `levit_flutter`).

## Conceptual Overview

A `LevitScope` contains registrations plus optional parent linkage.
Resolution starts local and delegates to parent scopes when needed.
Child scopes can override parent registrations without mutating parent state.

Two access styles are available:

- Explicit: hold a `LevitScope` reference and call methods directly.
- Contextual: use `Ls.currentScope` within a scope-run execution context.

## Getting Started

```yaml
dependencies:
  levit_scope: ^latest
```

```dart
import 'package:levit_scope/levit_scope.dart';

class ApiClient {}

void main() {
  final appScope = LevitScope.root('app');
  final featureScope = appScope.createScope('feature');

  featureScope.put(() => ApiClient());

  featureScope.run(() {
    final client = Ls.find<ApiClient>();
    assert(client is ApiClient);
  });

  featureScope.dispose();
  appScope.dispose();
}
```

## Middleware Lifecycle (Token-Based)

Use one token per concern so updates are idempotent and teardown is explicit:

```dart
import 'package:levit_scope/levit_scope.dart';

const auditToken = #di_audit;

class AuditMiddleware extends LevitScopeMiddleware {}

void configure() {
  LevitScope.addMiddleware(AuditMiddleware(), token: auditToken);
}

void reconfigure() {
  LevitScope.addMiddleware(AuditMiddleware(), token: auditToken);
}

void teardown() {
  LevitScope.removeMiddlewareByToken(auditToken);
}
```

## Design Principles

- Deterministic teardown: disposal order is controlled and explicit.
- Scope isolation: child scope overrides do not leak upward.
- Reflection-free contracts: type/tag keying is explicit and stable.
- Middleware-first extensibility: interception hooks are part of the runtime contract.

