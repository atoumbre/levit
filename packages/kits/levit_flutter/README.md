# levit_flutter

[![Pub Version](https://img.shields.io/pub/v/levit_flutter)](https://pub.dev/packages/levit_flutter)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter` is the recommended single import for Flutter applications using Levit.

This kit composes:

- `levit_flutter_core` widget bindings.
- `levit_dart` controller utility layer.
- Flutter-specific mixins/widgets in this package.

This package is responsible for ergonomic adoption, not replacing core behavior.
Add `levit_monitor` separately when you need runtime telemetry; this kit keeps observability opt-in.

## Conceptual Overview

`levit_flutter` keeps runtime semantics in core packages and adds practical Flutter integrations:

- Lifecycle-aware controller mixins that react to app lifecycle.
- Native observation adapters, overlay scope bridging and optional keep-alive.
- Unified import surface for common Flutter usage.

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
```

Enable ownership capture before mounting the app:

```dart
void main() {
  Levit.enableAutoLinking();
  runApp(const MaterialApp(home: CounterPage()));
}
```

## Overlays

Use `showLevitDialog` / `showLevitModalBottomSheet` when an imperative overlay
must resolve page- or app-local dependencies with `context.levit.find`
(they wrap content with `LScope.capture`).

## Design Principles

- Widget-tree ownership for scopes and controller lifecycles.
- Fine-grained rebuild behavior inherited from reactive core bindings.
- Composition-first kit design with explicit package boundaries.

See the [0.1.0 migration guide](https://github.com/softilab/levit/blob/main/MIGRATION_0.1.0.md) before upgrading.


### Local mount hooks

Use a local `StatefulWidget` when a subtree needs mount/unmount callbacks.
The [MountObserver example](example/lib/mount_observer.dart) demonstrates
`initState` and `dispose`. It reports widget lifetime, not viewport visibility.
Own asynchronous cleanup in a scope and await its lifecycle controller's `closed`
signal from tests or the surrounding feature boundary. `LKeepAlive` remains
available for deliberate offscreen retention.

## Stable query observations in 0.1.0

`LBuilder`, `LSelectorBuilder` and `LStatusBuilder` observe `LxReadable<T>`.
Pass an async-map entry directly so mounted widgets stay connected across refresh.
`LStatusBuilder.onWaiting`, `onError` and `onIdle` receive their complete status:

```dart
LStatusBuilder<List<Item>>(
  controller.queries.entry(search),
  onWaiting: (status) => status.hasLastValue
      ? ItemList(status.lastValue!) : const CircularProgressIndicator(),
  onError: (status) => Text('Refresh failed: ${status.error}'),
  onSuccess: (items) => ItemList(items),
);
```

Check `hasLastValue` rather than `lastValue != null` for nullable results. Keep
query/mutation ownership in the controller; widgets observe handles and invoke
controller actions. The async catalog example demonstrates searchable pagination,
retained results and optimistic favorite edits with rollback.

## Borrowing ValueListenable interoperability (0.1.0)

Use `source.asValueListenable()` when a Flutter API needs a `ValueListenable<T>`.
It accepts any `LxReadable<T>`, including observation-only state and stable async-map
entries. Keep the adapter outside `build` and give it a controller or widget owner:

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

`LxValueListenable<T>` borrows the source. Creating it does not subscribe; the first
listener subscribes and removing the last listener unsubscribes. Reads return the
current source value, including null, and source refreshes are forwarded even when
the same mutable object is retained. Duplicate listeners follow Flutter conventions.

`adapter.dispose()` is idempotent, stops notifications and releases only the
subscription. It never closes or mutates the source. Reads/new listeners after
adapter disposal throw `StateError`; removing listeners remains safe during widget
teardown. Keep the source alive under its existing owner. Expose the adapter as
`ValueListenable<T>` to observation-only consumers.

For native Levit widgets, keep using `LWatch` or `LBuilder`. This adapter provides
interoperability with Flutter's existing APIs and adds no persistence dependency.

Run `flutter run -t lib/countdown_interop.dart` from `example/` for a feature-owned
countdown displayed through ValueListenableBuilder with pause, resume and restart.

Start with [scopes → owners → state → widgets](../../../docs/ONBOARDING.md).
Selection/time, numeric helpers, keep-alive, static dependencies and async batching
are covered in [advanced documentation](../../../docs/ADVANCED.md).
Requires Dart 3.12+ and Flutter 3.44+.
