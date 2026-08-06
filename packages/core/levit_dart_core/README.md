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
- Any `LevitResourceOwner` owns resources registered through `own` or
  `autoDispose`.
- A `LevitStore` is a portable state definition that resolves per scope.

The package preserves explicit scoping and avoids hidden global behavior.

## Getting Started

```yaml
dependencies:
  levit_dart_core: ^latest
```

```dart
import 'package:levit_dart_core/levit_dart_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() => count(count() + 1);

  @override
  void onInit() {
    super.onInit();
    autoDispose(count);
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

`own` and `autoDispose` are equivalent. Cleanup is idempotent, awaited, and
LIFO; `disposed` completes after terminal cleanup. With auto-linking enabled,
reactives created while any returned `LevitResourceOwner` is constructed are
linked to that owner.

Always delegate lifecycle overrides to `super`:

```dart
@override
Future<void> onClose() async {
  await flushPendingWrites();
  await super.onClose();
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
