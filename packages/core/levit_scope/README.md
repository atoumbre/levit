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
  levit_scope: ^0.1.0-beta.1
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
Deletion/disposal middleware failures are included in that aggregate. They do
not skip later observers or resource cleanup. Deleting a non-owning alias still
leaves its canonical instance alive when a deletion observer fails.

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

## Factory ownership

Factory results implementing `LevitScopeDisposable` or `LevitDisposable` belong to the scope that registers the factory, including lookups through a child scope. Removal closes results in reverse creation order and awaits pending async construction. A result that arrives after removal is closed and rejected to its resolver. Factories survive ordinary resets only when registered with `permanent: true`; forced deletion/reset and scope disposal release them. Await deletion before replacement.

## 0.1.0 ownership contracts

Await `dispose`, `delete`, and `reset`: pending construction and initialization
finish before registered resources are released. `scope.disposed` remains
pending while the scope is active; await `dispose()` to receive cleanup errors.
Children created with `createScope` are owned by default and close before parent
dependencies. Use `ownedByParent: false` only for a borrowed relationship.
Factories are no longer implicitly permanent. Use explicit `permanent: true`
when needed, and await `releaseFactoryInstance(instance)` for early release.


### Typed stores and observation in 0.1.0

Store identity is the definition object plus its optional variant tag. Diagnostic
names and result types do not identify stores. Install `store.overrideWith(builder)`
using `scope.applyOverrides([...])` before local resolution. The receiving scope
owns override resources; unoverridden lookups inherit an ancestor unless
`localOnly: true` is supplied. `LevitRef` and `context.levit` offer `findStore`,
`findStore` and `findAsyncStore` with the same typed contract.

Optional DI lookups return null only for missing registrations. Builder and type
errors propagate. `scope.describe()` returns immutable ancestry, registration,
initialization and ownership metadata without dependency values or raw tags.
Builders and selectors accept `LxReadable<T>`; `LxState.asReadable` exposes this
observation-only interface.

Tests can import `package:levit/levit_testing.dart` or
`package:levit_flutter/levit_testing.dart`. Create `LevitTestScope(overrides: [...])`,
run code through its isolated scope, track asynchronous work and await `settle()`.
Register and await `close()` in teardown to report cleanup failures.

### Inspector lifecycle progress

`scope.describe().toJson()` describes ancestry, registrations, pending initialization,
ownership and closing state without dependency values. Optional middleware can
implement `LevitScopeProgressObserver` to receive changes while initialization and
cleanup are pending. The monitor uses these events for its cleanup view.

Registration-tracked initialization is drained to completion, including further
work adopted during draining. Disposal reports those failures after all cleanup
attempts; a late initialization failure cannot turn cleanup into a false success.

Use `await scope.runInitialization(() async { /* setup */ })` for external setup.
It admits the work before invoking the callback, drains it on scope closure, and
rejects disposal from initialization that would wait on itself. Async DI builders
receive the same execution guard. `trackInitialization(future)` still adopts
already-started work, whose original execution context cannot be changed.

`delete`, `reset` and `releaseFactoryInstance` reject self-disposal before
changing registrations. Early factory release waits for admitted initialization,
requests cancellation, drains work, and only then closes the instance. Concurrent
releases remain independent; scope closure waits for every admitted release.
Releasing instances retain their execution boundary until cleanup finishes, and
release failures also propagate through subsequent registration/scope cleanup.

Factory/initialization bookkeeping is allocated when used. Ordinary singleton
registrations preserve the same ownership contract without allocating unused
factory collections. Synchronous cleanup does not introduce an extra future;
real asynchronous cleanup is still awaited, with failures collected after every
attempt. The `disposed` signal can first be observed before or after closure;
it completes after cleanup and remains pending while the scope is active.
Closing registrations retain their execution guards while their work drains.
Removing a dependency from lookup does not allow its task to await the same
scope's disposal. A scope publishes one stable disposal future before callbacks
run, and uses asynchronous continuations only when cleanup or children require
them; synchronous failures remain observable through that awaited future.
