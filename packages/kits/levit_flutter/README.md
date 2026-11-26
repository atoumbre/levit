# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter` is the recommended single import for Flutter applications using
Levit. It composes `levit_flutter_core`, `levit_dart`, and Flutter-specific
helpers behind one entry point while keeping `levit_monitor` opt-in.

## What's Included

| Entry point | Provides |
| :-- | :-- |
| `package:levit_flutter/levit_flutter.dart` | Scopes (`LScope`, `LAsyncScope`, `LRouteScope`, `LevitScopeLifecycleController`), views & builders (`LWatch`, `LBuilder`, `LSelectorBuilder`, `LStatusBuilder`, `LView`, `LScopedView`), `asValueListenable()`, `showLevitDialog` / `showLevitModalBottomSheet`, `LKeepAlive`, `LevitAppLifecycleMixin`, `LevitLoopLifecycleMixin`, plus the full `levit_dart` runtime (`LevitController`, `LevitStore`, reactives, `LevitAsyncMap`, task/time/selection/loop mixins). |
| `package:levit_flutter/tasks.dart` | Advanced task orchestration types: `LevitTaskGroup`, `LevitRetryPolicy`, `LevitTaskMiddleware`, and `LevitTaskTracker`. |
| `package:levit_flutter/levit_testing.dart` | `LevitTestScope` for isolated store overrides, async tracking, and awaited teardown in tests. |

## Getting Started

```yaml
dependencies:
  levit_flutter: ^0.1.0-beta.1
```

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count.value++;
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView<CounterController>.put(
      () => CounterController(),
      // autoWatch is true by default — read reactives directly; no outer LWatch.
      builder: (context, controller) => Scaffold(
        body: Center(
          child: Text('Count: ${controller.count()}'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: controller.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

void main() {
  Levit.enableAutoLinking();
  runApp(const MaterialApp(home: CounterPage()));
}
```

## Overlays & Subtree Lifecycle

- **Imperative overlays:** Use `showLevitDialog` and `showLevitModalBottomSheet`
  so dialogs and bottom sheets automatically inherit the caller's `LScope`
  (via `LScope.capture`) and can resolve page-local dependencies with
  `context.levit.find`.
- **Keep-alive & mount hooks:** Use `LKeepAlive` for deliberate offscreen
  retention inside scroll views. For widget-lifetime mount/unmount callbacks,
  use a local `StatefulWidget` as shown in the
  [MountObserver example](https://github.com/softilab/levit/blob/main/packages/kits/levit_flutter/example/lib/mount_observer.dart).

## Stable Query Observations

`LBuilder`, `LSelectorBuilder`, and `LStatusBuilder` observe `LxReadable<T>`.
Pass a `LevitAsyncMap` entry directly so mounted widgets stay connected across
refreshes, and check `status.hasLastValue` (rather than `lastValue != null`)
when `T` is nullable:

```dart
LStatusBuilder<List<Item>>(
  controller.queries.entry(search),
  onWaiting: (status) => status.hasLastValue
      ? ItemList(status.lastValue!)
      : const CircularProgressIndicator(),
  onError: (status) => Text('Refresh failed: ${status.error}'),
  onSuccess: (items) => ItemList(items),
);
```

See the [async catalog example](https://github.com/softilab/levit/tree/main/examples/async_catalog)
for searchable pagination, retained results, and optimistic updates with rollback.

## Borrowing ValueListenable Interoperability

Use `source.asValueListenable()` when a Flutter API expects a `ValueListenable<T>`.
Create and own the adapter outside `build`:

```dart
class CounterController extends LevitController {
  late final count = own(0.lx);
  late final display = own(count.asValueListenable());
}

ValueListenableBuilder<int>(
  valueListenable: controller.display,
  builder: (_, value, __) => Text('$value'),
);
```

- **Lazy borrowing:** Subscribes on the first listener and unsubscribes when the
  last listener is removed; never closes or mutates the source.
- **Idempotent disposal:** `adapter.dispose()` detaches listeners cleanly; reads
  or new listeners after disposal throw `StateError`, while listener removal
  remains safe during widget teardown.
- **Scoped interop example:** Run `flutter run -t lib/countdown_interop.dart`
  from `example/` for a feature-owned countdown rendered through
  `ValueListenableBuilder`.

## Design Principles

- **Widget-tree ownership:** scopes and controller lifecycles align with mount/unmount.
- **Fine-grained rebuilds:** reactive reads drive focused subtree updates.
- **Thin kit composition:** runtime semantics stay in core packages with explicit boundaries.

Start with [scopes → owners → state → widgets](https://github.com/softilab/levit/blob/main/docs/ONBOARDING.md)
and [advanced documentation](https://github.com/softilab/levit/blob/main/docs/ADVANCED.md).
Requires Dart 3.12+ and Flutter 3.44+.
