# levit_dart_core

[![Pub Version](https://img.shields.io/pub/v/levit_dart_core)](https://pub.dev/packages/levit_dart_core)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart_core` is the composition layer that integrates:

- `levit_scope` for dependency injection and lifecycle ownership.
- `levit_reactive` for state propagation and derivation.

This package is responsible for:

- `Levit`: a unified facade over DI, reactive batching, and middleware registration.
- `LevitController` and `LevitResourceOwner`: lifecycle-aware ownership units.
- `LevitStore` / `LevitAsyncStore`: reusable scoped state factories.

This package does not include:

- Flutter widgets and widget-tree bindings (use `levit_flutter_core` or `levit_flutter`).
- Higher-level utility mixins for tasks/loops (use `levit_dart`).

`levit_flutter_core` re-exports this package for convenience in Flutter, but the Dart-side composition APIs and lifecycle semantics remain owned and documented here.

## Conceptual Overview

`levit_dart_core` formalizes ownership semantics between state and lifecycle:

- A `LevitScope` owns registrations and deterministic teardown.
- Any `LevitResourceOwner` owns resources registered through `own`.
- A `LevitStore` is a portable state definition that resolves per scope.

The package preserves explicit scoping and avoids hidden global behavior.

## Getting Started

```yaml
dependencies:
  levit_dart_core: ^0.1.0-beta.1
```

```dart
import 'package:levit_dart_core/levit_dart_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() => count.value++;

  @override
  void onInit() {
    super.onInit();
    own(count);
  }
}

Future<void> main() async {
  final scope = Levit.createScope('app');

  scope.run(() {
    Levit.put(() => CounterController());
    Levit.find<CounterController>().increment();
  });

  await scope.dispose();
}
```

## Resource Ownership

Controllers, stores, and non-controller resources can share one ownership
contract:

```dart
final class SessionResource extends LevitScopeDisposable
    with LevitResourceOwnership {
  late final subscription = own(events.listen(handleEvent));
  late final refreshTimer = own(Timer.periodic(
    const Duration(minutes: 1),
    (_) => refresh(),
  ));
}
```

`own` registers supported resources or an explicit disposer. Cleanup is idempotent, awaited, and
LIFO; `disposed` completes after terminal cleanup. With auto-linking enabled,
reactives created while any returned `LevitResourceOwner` is constructed are
linked to that owner. A nested lookup keeps its own registration's lifetime,
including when a page first constructs a lazy app dependency.

Always delegate lifecycle overrides to `super`:

```dart
import 'dart:async';

// Inside a resource-owning controller:
@override
FutureOr<void> onBeforeClose() async {
  await super.onBeforeClose();
  await flushPendingWrites();
}
```

Use `Levit.bindExisting<Port, Implementation>()` after registering an
implementation when several interface types should resolve to the same owned
instance. This is deliberately smaller than a module system: it does not add a
second composition abstraction or transactional graph replacement.

## Design Principles

- Explicit ownership: scopes own registrations; controllers own cleanup.
- Deterministic lifecycle: setup and teardown order is predictable.
- Composition over abstraction leakage: `Levit` exposes scope and reactive APIs directly.
- Pure Dart portability: usable in shared logic, servers, and CLIs.

## Store inheritance and cleanup preparation

Store builders run once. Return a reactive object for evolving state, or use `LxComputed` for reactive derivation. A lookup reuses an ancestor store by default. Pass `localOnly: true` to a store lookup or a store-specific `LevitRef` lookup to create/reuse only the current scope’s instance.

Override `onBeforeClose` when work must finish before owned resources close. Closing is already set when this hook runs; new resources cannot be owned. Always await/delegate `super.onBeforeClose()`. The owner then performs awaited LIFO cleanup and aggregates failures.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md) before upgrading.

## 0.1.0 resource ownership

An owner requests cancellation across its asynchronous work, drains that work,
then releases remaining resources in reverse ownership order. Await `onClose()`
or the owning scope's disposal. Async initialization capture belongs to this
lifetime too. Owned work must request cancellation rather than dispose its own
owner from inside its callback.

Use `own(resource, dispose: (resource) => resource.dispose())` for third-party
resources. Arbitrary method-name guessing is no longer supported. Built-in
reactives, Levit resources, subscriptions, timers, sinks and cleanup callbacks
have typed adapters. `LevitRef.onDispose` accepts asynchronous callbacks.


### Typed stores and observation in 0.1.0

Store identity is the definition object plus its optional variant tag. Diagnostic
names and result types do not identify stores. Install `store.overrideWith(builder)`
using `scope.applyOverrides([...])` before local resolution. The receiving scope
owns override resources; unoverridden lookups inherit an ancestor unless
`localOnly: true` is supplied. `LevitRef` and `context.levit` offer `findStore`,
`findStoreAsync`, and `findAsyncStore` with the same typed contract.

Optional DI lookups return null only for missing registrations. Builder and type
errors propagate. `scope.describe()` returns immutable ancestry, registration,
initialization and ownership metadata without dependency values or raw tags.
Builders and selectors accept `LxReadable<T>`; `LxState.asReactive` exposes this
observation-only interface.

Tests can import `package:levit/levit_testing.dart` or
`package:levit_flutter/levit_testing.dart`. Create `LevitTestScope(overrides: [...])`,
run code through its isolated scope, track asynchronous work and await `settle()`.
Register and await `close()` in teardown to report cleanup failures.

Captured async controller and store initialization cannot dispose its own owner
or containing scope: this throws `StateError` instead of deadlocking. Request
cancellation from the initializer and await cleanup from outside that execution.
The guard expires when initialization settles; later callbacks may close normally.
