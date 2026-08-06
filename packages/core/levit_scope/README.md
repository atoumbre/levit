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
- Deterministic, awaited cleanup through explicit scope disposal.
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

Future<void> main() async {
  final appScope = LevitScope.root('app');
  final featureScope = appScope.createScope('feature');

  featureScope.put(() => ApiClient());

  featureScope.run(() {
    final client = Ls.find<ApiClient>();
    assert(client is ApiClient);
  });

  await featureScope.dispose();
  await appScope.dispose();
}
```

## Awaited Disposal

`LevitScopeDisposable.onClose()` and `LevitDisposable.dispose()` may be
asynchronous. Always await `delete`, `reset`, and `dispose`:

```dart
final scope = LevitScope.root('app');
scope.put(() => DatabaseConnection());

await scope.delete<DatabaseConnection>();
await scope.dispose();
```

Cleanup is LIFO and best-effort. If more than one resource fails to close,
Levit finishes the remaining cleanup and then throws one
`LevitDisposalException` containing every failure.

An instantiated synchronous registration is never silently overwritten. Delete
and await the old registration before putting its replacement.

## Existing-Instance Aliases

Use `bindExisting` when one owned singleton implements several ports:

```dart
abstract interface class Reader {}
abstract interface class Writer {}
final class Repository implements Reader, Writer {}

scope.put(() => Repository());
scope.bindExisting<Reader, Repository>();
scope.bindExisting<Writer, Repository>();

assert(identical(scope.find<Reader>(), scope.find<Writer>()));
```

Aliases are local, non-owning, and cannot target factory registrations.
Deleting an alias leaves the canonical instance alive; deleting the canonical
registration removes its aliases and disposes the instance once.

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

- Deterministic teardown: disposal is awaited, LIFO, and failure-aggregating.
- Scope isolation: child scope overrides do not leak upward.
- Reflection-free contracts: type/tag keying is explicit and stable.
- Middleware-first extensibility: interception hooks are part of the runtime contract.
