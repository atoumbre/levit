# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter_core` owns the Flutter binding layer for Levit, bridging Flutter
`InheritedWidget` tree lifecycles with Levit `Zone`-based scopes. It also
re-exports `levit_dart_core` for convenience.

Use this package directly when you want Flutter bindings without the
higher-level `levit_dart` utilities and overlay/lifecycle helpers bundled in
[`levit_flutter`](https://pub.dev/packages/levit_flutter).

## Choosing the Right Widget

| API | Use when | Prefer another API when |
| :-- | :-- | :-- |
| `LWatch` | A small subtree should rebuild for whichever reactive values it reads during build. | The dependency is already explicit and singular; prefer `LBuilder`. |
| `LBuilder` | You already know the exact `LxReadable` / `LxReactive` to observe. | The subtree depends on several reactive reads discovered during build; prefer `LWatch`. |
| `LSelectorBuilder` | You want a small derived value local to one subtree without promoting it to controller state. | The derived value is shared across widgets or long-lived; move it into a controller/store computed. |
| `LStatusBuilder` | You are rendering an `LxStatus<T>` with waiting, error, idle, and success branches. | You are not working with `LxStatus`; prefer `LBuilder` or `LWatch`. |
| `LView` | The controller/service already exists in the nearest scope and you only need to render it. | The widget should create and own a child scope; prefer `LScopedView`. |
| `LAsyncView` | The dependency resolves asynchronously from the current scope. | You also need to create a new scope boundary; compose `LScope` or `LAsyncScope` with `LView` / `LAsyncView`. |
| `LScopedView` | One widget should create a child scope, register a dependency, and render it. | The scope already exists (`LView`) or needs async initialization (`LAsyncScope` + `LView` / `LAsyncView`). |
| `LScope` / `LAsyncScope` | You need a sync or async scope boundary for a subtree (compose with `LView` / `LAsyncView` as needed). | A single synchronous controller-view pair is enough; prefer `LScopedView`. |
| `LRouteScope` / `LAsyncRouteScope` | Route identity and route visibility are the ownership boundary. | The scope is only subtree-local; prefer `LScope` or `LAsyncScope`. |

## Getting Started

```yaml
dependencies:
  levit_flutter_core: ^0.1.0
```

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class CounterController extends LevitController {
  final count = 0.lx;
  void increment() => count.value++;
}

void main() {
  Levit.enableAutoLinking();
  runApp(
    MaterialApp(
      home: LScope.put(
        () => CounterController(),
        child: Builder(
          builder: (context) {
            final controller = context.levit.find<CounterController>();
            return Scaffold(
              body: Center(
                child: LWatch(() => Text('Count: ${controller.count()}')),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: controller.increment,
                child: const Icon(Icons.add),
              ),
            );
          },
        ),
      ),
    ),
  );
}
```

## Route-Aware Scoping & Overlay Capture

Use `LRouteScope` / `LAsyncRouteScope` when a route is the lifetime boundary;
both reset the local scope when the bound route changes and expose a reactive
`LRouteVisibility` signal via `LRouteScope.visibilityOf(context)`:

```dart
Navigator(
  pages: [
    MaterialPage(
      key: const ValueKey('profile-route'),
      child: LRouteScope.put(
        () => ProfileController(),
        child: Builder(
          builder: (context) {
            final visibility = LRouteScope.visibilityOf(context)!;
            return LBuilder<LRouteVisibility>(
              visibility,
              (state) => Text('Route is ${state.name}'),
            );
          },
        ),
      ),
    ),
  ],
  onPopPage: (route, result) => route.didPop(result),
);
```

For dialogs and overlays rendered under a separate route subtree, wrap their
content with `LScope.capture(context, child: ...)` so `context.levit.find` still
resolves page-local dependencies (when using the `levit_flutter` kit,
`showLevitDialog` and `showLevitModalBottomSheet` wrap with `LScope.capture`
automatically):

```dart
showDialog(
  context: context,
  builder: (_) => LScope.capture(
    context,
    child: const Dialog(child: Text('Still inside the page scope')),
  ),
);
```

## Serialized Scope Replacement & View Updates

Pass a stable `LevitScopeLifecycleController` to `LScope` or `LAsyncScope` to
observe transitions (`settled`, `error`), retry failed setups (`retry()`), and
await terminal cleanup (`close()`):

```dart
LAsyncScope(
  lifecycle: lifecycle,
  args: [sessionId],
  configure: (scope) async {
    scope.put(() => SessionConnection(sessionId));
  },
  loading: (_) => const Center(child: CircularProgressIndicator()),
  error: (_, error) => TextButton(
    onPressed: lifecycle.retry,
    child: Text('Retry ($error)'),
  ),
  child: const SessionBody(),
);
```

- **Serialized & coalesced:** Rapid argument changes coalesce to the latest
  configuration while the previous generation finishes cleanup; an obsolete
  initializer cannot close a newer scope.
- **View resolution:** Consuming `LView` / `LAsyncView` resolve on mount, scope
  change, or explicit `args` change—a new resolver closure alone does not
  refetch. Pass `localOnly: true` to `.store` constructors or use
  `context.levit.findStore` / `findAsyncStore` for typed stores.
- **Unmount & self-disposal:** Widget `dispose()` starts cleanup synchronously
  and reports failures via `FlutterError.reportError` (and through awaited
  `lifecycle.close()`). Scope factories run inside `scope.runInitialization` and
  throw `StateError` if they attempt to await their own scope's disposal.

## Status Builders & ValueListenable Interoperability

- **`LxReadable<T>` builders:** `LBuilder`, `LSelectorBuilder`, and
  `LStatusBuilder` accept any `LxReadable<T>`. `LStatusBuilder.onWaiting`,
  `onError`, and `onIdle` receive the full `LxStatus<T>` (check
  `status.hasLastValue` rather than `lastValue != null` for nullable data).
- **`ValueListenable` adapter:** Use `source.asValueListenable()` when a Flutter
  API requires a `ValueListenable<T>`. Create and own the adapter outside
  `build`—it subscribes lazily on first listener, unsubscribes when the last
  listener leaves, and `dispose()` detaches without closing the source:

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

## Design Principles

- **Tree-owned lifecycles:** widget mount/unmount drives scope setup and disposal.
- **Fine-grained rebuilds:** widgets rebuild only for values read during build.
- **Explicit composition:** sync and async scope/view variants remain distinct.
