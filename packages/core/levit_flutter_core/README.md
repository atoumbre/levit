# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_flutter_core` owns the Flutter binding layer for Levit.

Use this package directly when you want Flutter bindings without the higher-level `levit_flutter` kit.

This package is responsible for:

- `LScope` / `LAsyncScope` / `LRouteScope` / `LAsyncRouteScope`: scope boundaries for subtree, async, and route-owned lifetimes.
- `LWatch`: reactive rebuild boundaries based on accessed values.
- `LView`, `LAsyncView`, `LScopedView`: controller/view orchestration widgets.
- Builder widgets (`LBuilder`, selector/status builders) for focused reactive rendering.

This package also re-exports `levit_dart_core` for convenience, so `Levit`, `LevitController`, stores, and reactive primitives remain available from one import.

This package does not include:

- Higher-level convenience widgets and runtime helpers provided by `levit_flutter`.
- New Dart runtime semantics beyond what `levit_dart_core` already defines.

## Conceptual Overview

`levit_flutter_core` bridges two scope models:

- Flutter tree scope via `InheritedWidget`.
- Levit execution scope via `Zone`-based current scope.

The package ensures widget lifecycle events and DI lifecycle events stay synchronized, so registrations created for a subtree are disposed when that subtree unmounts.

## Choosing the Right Widget

| API | Use when | Prefer another API when |
| :-- | :-- | :-- |
| `LWatch` | A small subtree should rebuild for whichever reactive values it reads during build. | The dependency is already explicit and singular; prefer `LBuilder`. |
| `LBuilder` | You already know the exact `LxReactive` to observe. | The subtree depends on several reactive reads discovered during build; prefer `LWatch`. |
| `LSelectorBuilder` | You want a small derived value local to one subtree without promoting it to controller state. | The derived value is shared across widgets or long-lived; move it into a controller/store computed. |
| `LStatusBuilder` | You are rendering an `LxStatus<T>` with waiting, error, and success branches. | You are not working with `LxStatus`; prefer `LBuilder` or `LWatch`. |
| `LView` | The controller/service already exists in the nearest scope and you only need to render it. | The widget should create and own a child scope; prefer `LScopedView`. |
| `LAsyncView` | The dependency resolves asynchronously from the current scope. | You also need to create a new scope boundary or async scope initialization; prefer `LAsyncScopedView` or `LAsyncScope`. |
| `LScopedView` | One widget should create a child scope, register a dependency, and render it. | The scope already exists; prefer `LView`. |
| `LAsyncScopedView` | One widget should create a child scope and resolve the dependency asynchronously. | You only need an async scope boundary without the view abstraction; prefer `LAsyncScope`. |
| `LScope` / `LAsyncScope` | You need a scope boundary for a subtree, independent of a specific controller/view widget. | A single controller-view pair is enough; prefer `LScopedView` or `LAsyncScopedView`. |
| `LRouteScope` / `LAsyncRouteScope` | Route identity and route coverage are the ownership boundary, and you want current/covered route visibility exposed reactively. | The scope is only subtree-local and does not care about route semantics; prefer `LScope` or `LAsyncScope`. |

## Getting Started

```yaml
dependencies:
  levit_flutter_core: ^0.1.0-beta.1
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

## Route-aware Scoping

Use `LRouteScope` when a screen route is the meaningful lifetime boundary.
Use `LAsyncRouteScope` when the same route-owned boundary also needs async initialization.
Both wrap the existing scope primitives, reset the local scope when the bound route changes, and expose a reactive `LRouteVisibility` signal to descendants.

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

## Capturing Scope for Dialogs and Overlays

Use `LScope.capture(...)` when a dialog or overlay should keep access to a page-local scope even though it is rendered under a different route subtree.

```dart
showDialog(
  context: context,
  builder: (_) => LScope.capture(
    context,
    child: const Dialog(child: Text('Still inside the page scope')),
  ),
);
```

Prefer the kit helpers from `package:levit_flutter/levit_flutter.dart`, which
capture by default for imperative overlays:

```dart
showLevitDialog(
  context: context,
  builder: (dialogContext) => Dialog(
    child: Text(dialogContext.levit.find<PageController>().title()),
  ),
);

showLevitModalBottomSheet(
  context: context,
  builder: (sheetContext) => Text(
    sheetContext.levit.find<PageController>().title(),
  ),
);
```

Routed sheets (for example a `ModalBottomSheetPage`) should still wrap their
content with `LScope.capture` when they need page-local dependencies.

## Design Principles

- Tree-owned lifecycles: widget mount/unmount controls scope setup/disposal.
- Fine-grained rebuilds: widgets rebuild only for values read during build.
- Explicit composition: sync and async scope/view variants remain explicit.
- Focused ownership: package owns Flutter bindings and re-exports the Dart core layer for convenience.

## View updates and local stores

Consuming views resolve initially, when their bound scope changes, or when explicit `args` change. A new resolver closure alone does not refetch. Scoped views continue recreating their scope when ownership arguments change. Pass `localOnly: true` to `.store` constructors to isolate a store from ancestor instances. Register shared dependencies explicitly in their owning scope; use `LScopedView.put` or `LAsyncScopedView.put` for view-owned dependencies.

## 0.1.0 scope replacement

Scope replacement is serialized. While the previous generation initializes or
closes, `LScope` and `LAsyncScope` render their `loading` builder. Rapid changes
coalesce to the latest arguments. Errors render through `error`; an obsolete
initializer cannot close a newer scope.

Pass a stable `LevitScopeLifecycleController` as `lifecycle` to observe
`settled`, inspect `error`, retry a failed transition with `retry()`, and await
terminal cleanup with `close()`. Widget `dispose()` initiates this operation
synchronously; it cannot await it. Unmount cleanup failures are reported via
`FlutterError.reportError` and remain available from awaited `close()`.


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

Reentrant scope replacement is serialized too: initialization is admitted before
calling the factory, so a replacement requested inside it still drains that
initializer. A close requested by a lifecycle listener completes only after the
resulting cleanup pump finishes. Await `close()` to observe cleanup failures.

Widget factories run through `scope.runInitialization`. They cannot await their
own scope, parent owner, or lifecycle controller's terminal cleanup; those calls
fail with `StateError`. Initiate cancellation there and await cleanup externally.
