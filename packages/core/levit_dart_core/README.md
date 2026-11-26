# levit_dart_core

[![Pub Version](https://img.shields.io/pub/v/levit_dart_core)](https://pub.dev/packages/levit_dart_core)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_dart_core` composes `levit_scope` and `levit_reactive` into Levit's
unified Dart lifecycle and ownership layer.

Building an application? Start with [`levit`](https://pub.dev/packages/levit)
(pure Dart) or [`levit_flutter`](https://pub.dev/packages/levit_flutter)
(Flutter) unless you want core composition APIs without the task/query/timer
utilities in `levit_dart`. `levit_flutter_core` also re-exports this package for
Flutter convenience.

This package owns:

- `Levit`: unified facade over scoped DI, reactive batching, and middleware.
- `LevitController`: lifecycle-aware ownership unit with `own(...)`,
  `onInit`, `onBeforeClose`, and `onClose`.
- `LevitStore` and `LevitAsyncStore`: portable, typed per-scope state recipes.
- `package:levit_dart_core/levit_testing.dart`: `LevitTestScope` for isolated
  override testing and awaited teardown.

## Getting Started

```yaml
dependencies:
  levit_dart_core: ^0.1.0
```

```dart
import 'package:levit_dart_core/levit_dart_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() => count.value++;

  @override
  void onInit() {
    super.onInit();
    // Explicit ownership when Levit.enableAutoLinking() is not enabled.
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

## Resource Ownership & Lifecycle Hooks

Extend `LevitController` whenever a controller or service owns reactives,
timers, subscriptions, or custom disposables (or implement `LevitDisposable`
for simple 1-method `dispose()` services):

```dart
final class SessionService extends LevitController {
  SessionService(Stream<Event> events) {
    own(events.listen(handleEvent));
    own(Timer.periodic(const Duration(minutes: 1), (_) => refresh()));
  }

  void handleEvent(Event event) {}
  void refresh() {}
}
```

- **Typed `own(...)`:** Built-in reactives, Levit disposables, `StreamSubscription`,
  `Timer`, `Sink`, and cleanup callbacks are adapted automatically. For
  third-party types, pass an explicit disposer:
  `own(resource, dispose: (r) => r.dispose())` (no reflective method-name
  guessing).
- **Auto-linking:** When `Levit.enableAutoLinking()` is enabled, reactives
  created during construction/init of any returned `LevitController` link to
  that controller, while nested dependency lookups keep their own registration's
  lifetime.
- **Ordered cleanup (`onBeforeClose` → LIFO `onClose`):** Override
  `onBeforeClose` for async preparation that must complete before owned
  resources close (closing is already active; new resources cannot be owned).
  Always delegate to `super.onInit()`, `await super.onBeforeClose()`, and
  `await super.onClose()`.
- **Self-disposal guard:** Captured async initializers cannot dispose their own
  owner or containing scope (`StateError`); request cancellation inside the
  initializer and await disposal externally.
- **Aliases:** Use `Levit.bindExisting<Port, Implementation>()` to bind multiple
  interfaces to one owned singleton.

## Stores & Scoped Overrides

`LevitStore` and `LevitAsyncStore` define reusable state recipes identified by
the definition object plus optional variant tag. Child scopes inherit an
ancestor store by default unless `localOnly: true` or a local override is
installed via `scope.applyOverrides([...])`:

```dart
final counterStore = LevitStore((ref) => ref.own(0.lx));

Future<void> main() async {
  final parent = Levit.createScope('parent');
  try {
    final base = counterStore.findIn(parent);
    final child = parent.createScope('child');
    child.applyOverrides([counterStore.overrideWith((ref) => ref.own(10.lx))]);

    final local = counterStore.findIn(child);
    print('${base.value}, ${local.value}'); // 0, 10
  } finally {
    await parent.dispose();
  }
}
```

Compose stores inside builders with `ref.findStore` / `ref.findAsyncStore` and
register async teardown callbacks with `ref.onDispose`.

## Testing

Import `package:levit_dart_core/levit_testing.dart` (re-exported by `levit` and
`levit_flutter`) for `LevitTestScope(overrides: [...])`, explicit future
tracking (`track` / `settle`), and awaited `close()` in `addTearDown` so
cleanup failures fail the test.

## Design Principles

- **Explicit ownership:** scopes own registrations; controllers and stores own cleanup.
- **Deterministic lifecycle:** awaited `onBeforeClose` → LIFO disposal with aggregated errors.
- **Pure Dart portability:** usable in shared domain logic, servers, and CLIs.
