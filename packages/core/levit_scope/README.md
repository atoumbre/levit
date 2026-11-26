# levit_scope

[![Pub Version](https://img.shields.io/pub/v/levit_scope)](https://pub.dev/packages/levit_scope)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_scope)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_scope)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_scope` is Levit's pure Dart dependency injection and lifecycle runtime.

Building an application? Start with [`levit`](https://pub.dev/packages/levit)
(pure Dart) or [`levit_flutter`](https://pub.dev/packages/levit_flutter)
(Flutter) unless you specifically want scoped DI standalone.

This package owns:

- Builder-based dependency registration (`put`, `lazyPut`, `lazyPutAsync`).
- Hierarchical parent/child scope resolution and local overrides.
- Deterministic, awaited LIFO cleanup (`dispose`, `delete`, `reset`).
- Non-owning singleton aliases (`bindExisting`) and scoped factory ownership.
- DI middleware interception and immutable scope inspection (`scope.describe()`).

Reactive state lives in `levit_reactive`; Flutter bindings live in
`levit_flutter_core` and `levit_flutter`.

## Getting Started

```yaml
dependencies:
  levit_scope: ^0.1.0
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

Use an explicit `LevitScope` reference directly, or `Ls.currentScope` /
`Ls.find` inside `scope.run(...)`.

## Awaited Disposal & Ownership Contracts

`LevitScopeDisposable.onClose()` and `LevitDisposable.dispose()` may be
asynchronous. Always await `delete`, `reset`, and `dispose`:

```dart
final scope = LevitScope.root('app');
scope.put(() => DatabaseConnection());

await scope.delete<DatabaseConnection>();
await scope.dispose();
```

- **LIFO & failure-aggregating:** Pending construction and initialization finish
  before registered resources close in reverse order. All cleanup attempts run;
  failures (including deletion/disposal middleware failures) are reported
  together in `LevitDisposalException`.
- **Owned children by default:** Child scopes created via `createScope` are
  owned by their parent (`ownedByParent: true`) and close before parent
  dependencies. Pass `ownedByParent: false` only for borrowed relationships.
- **No silent overwrites:** An instantiated synchronous registration cannot be
  overwritten in place—`await delete` first.
- **Self-disposal guard:** `delete`, `reset`, and `releaseFactoryInstance` throw
  `StateError` if called from inside an active initialization that would wait on
  itself. Wrap external setup work with `await scope.runInitialization(...)` to
  admit, drain, and guard it under the same contract.
- **Disposal observation:** `scope.disposed` stays pending while active and
  completes after cleanup; await `dispose()` to observe cleanup errors.

## Existing-Instance Aliases & Factories

Use `bindExisting` when one owned singleton implements multiple ports:

```dart
abstract interface class Reader {}
abstract interface class Writer {}
final class Repository implements Reader, Writer {}

scope.put(() => Repository());
scope.bindExisting<Reader, Repository>();
scope.bindExisting<Writer, Repository>();

assert(identical(scope.find<Reader>(), scope.find<Writer>()));
```

- **Aliases:** Local, non-owning, and singleton-only. Deleting an alias leaves
  the canonical instance alive; deleting the canonical registration removes its
  aliases and disposes the instance once.
- **Factory ownership (`isFactory: true`):** Disposable factory results belong
  to the registering scope (even when resolved through a child scope) and close
  in reverse creation order on removal or disposal. Factories are not implicitly
  permanent—pass `permanent: true` to survive non-forced `reset`, and await
  `releaseFactoryInstance(instance)` for early release.

## Overrides, Middleware & Inspection

- **Overrides & optional lookups:** Install overrides with
  `scope.applyOverrides([...])` before local resolution; the receiving scope
  owns override resources. Optional lookups (`findOrNull`, `findOrNullAsync`)
  return `null` only for missing registrations, while builder and type errors
  propagate.
- **Immutable inspection:** `scope.describe()` (and `.toJson()`) returns
  ancestry, registration, pending initialization, ownership, and closing state
  without exposing dependency values or raw tags. Implement
  `LevitScopeProgressObserver` to receive progress notifications during
  initialization and cleanup.
- **Middleware (token-based):** Use one stable token per concern for idempotent
  updates and explicit teardown:

```dart
import 'package:levit_scope/levit_scope.dart';

const auditToken = #di_audit;

class AuditMiddleware extends LevitScopeMiddleware {}

void configure() {
  LevitScope.addMiddleware(AuditMiddleware(), token: auditToken);
}

void teardown() {
  LevitScope.removeMiddlewareByToken(auditToken);
}
```

## Design Principles

- **Deterministic teardown:** disposal is awaited, LIFO, and failure-aggregating.
- **Scope isolation:** child scope overrides never mutate parent state.
- **Reflection-free contracts:** explicit type/tag keying with predictable middleware hooks.
