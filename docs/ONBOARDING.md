# Getting Started with Levit

Levit gives Dart and Flutter apps one simple mental model for **state,
dependencies, and cleanup**.

Requires **Dart 3.7+** (and **Flutter 3.29+** for Flutter apps; **Dart 3.12+** for the optional `levit_lints` analyzer plugin).

## The 30-Second Mental Model

Four ideas cover 90% of day-to-day Levit code:

1. **Bootstrap once in `main()`** — enable auto-linking and register app-wide
   dependencies in a root `LScope`.
2. **Put state & logic in controllers or stores** (`LevitController`, `LevitStore`).
3. **Attach feature lifecycles to scopes** (`LScopedView`, `LScope`). When a
   screen or scope closes, everything it created is disposed automatically.
4. **Read reactives in thin widgets** (`.lx`, `LxComputed`, `LWatch`,
   `LStatusBuilder`) so only what changed rebuilds.

---

## Step 1: Install & App Setup

Pick the single kit package for your target:

```bash
# Flutter app
flutter pub add levit_flutter:^0.1.0-beta.1

# Pure Dart (CLI, server, or shared domain package)
dart pub add levit:^0.1.0-beta.1
```

### Enable auto-linking and compose your root scope

In Flutter `main()`, do two things before mounting your UI:

1. **Call `Levit.enableAutoLinking()`** — any reactive state (`0.lx`,
   `LxComputed`, `LxWorker`, etc.) created during a controller's constructor or
   `onInit()` is automatically linked to that controller and closed when the
   controller disposes. Mounting an `LScope` or `LAsyncScope` also enables
   auto-linking automatically in Flutter unless you explicitly call
   `Levit.disableAutoLinking()`, but calling `Levit.enableAutoLinking()` in
   `main()` keeps startup explicit and covers controllers registered before the
   first scope mounts.
2. **Wrap your app in a root `LScope`** — register long-lived services and
   app-wide controllers once so every screen below can resolve them via
   `context.levit.find<T>()`:

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  Levit.enableAutoLinking();

  runApp(
    LScope(
      configure: (scope) {
        // Lazy services are created on first use:
        scope.lazyPut(() => ApiClient());
        scope.lazyPut(() => CatalogRepository(scope.find<ApiClient>()));

        // Eager app-wide controllers initialize immediately:
        scope.put(() => AuthController(scope.find<ApiClient>()));
      },
      child: const MaterialApp(home: HomePage()),
    ),
  );
}
```

> **Need async startup** (like loading saved preferences or restoring a session
> before showing the home screen)? Swap `LScope` for `LAsyncScope` with an
> `async` `configure` callback and a `loading` builder.

---

## Step 2: Build Your First Screen

For screen-local state, wrap your page in `LScopedView.put`. Levit creates the
controller when the page mounts, links its reactive fields automatically, and
disposes it when the page pops:

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
      builder: (context, controller) => Scaffold(
        appBar: AppBar(title: const Text('Counter')),
        body: Center(
          // Reading controller.count() subscribes this view automatically.
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

**How reading and writing work:**
- Read with `count()` or `count.value`.
- Write with `count.value = next` (or `count.value++`).

### Derived state & focused rebuilds on larger screens

`LScopedView` has `autoWatch: true` by default, which is convenient for compact
screens. On larger screens, set `autoWatch: false` and wrap only the widgets
that should rebuild in `LWatch`:

```dart
class CounterController extends LevitController {
  final count = 0.lx;
  late final LxComputed<int> doubled;

  @override
  void onInit() {
    super.onInit();
    // Created during onInit(), so auto-linking owns doubled too:
    doubled = LxComputed(() => count() * 2);
  }

  void increment() => count.value++;
}

// Inside build():
LScopedView<CounterController>.put(
  () => CounterController(),
  autoWatch: false,
  builder: (context, controller) => Scaffold(
    appBar: AppBar(title: const Text('Counter')), // Never rebuilds on count change
    body: Center(
      child: LWatch(
        () => Text('${controller.count()} × 2 = ${controller.doubled()}'),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: controller.increment,
      child: const Icon(Icons.add),
    ),
  ),
);
```

---

## Step 3: Share State Across Widgets and Features

Any widget under your root `LScope` (or a feature-level `LScope`) resolves
shared dependencies with `context.levit.find<T>()`:

```dart
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.levit.find<AuthController>();
    return LWatch(() => Text(auth.userName()));
  }
}
```

- **Feature subtrees:** Wrap a multi-screen flow (like checkout or onboarding)
  in its own `LScope` so its dependencies are shared inside the flow and
  automatically disposed when the flow exits.
- **Dialogs & bottom sheets:** Use `showLevitDialog` or
  `showLevitModalBottomSheet`—they automatically carry the caller's `LScope`
  into the overlay.

### Lightweight state recipes with `LevitStore`

When you want reusable state without writing a full controller class, define a
top-level `LevitStore` and resolve it in any scope:

```dart
final themeModeStore = LevitStore((ref) => ThemeMode.system.lx);

// Read from any widget under an LScope:
final mode = context.levit.findStore(themeModeStore);
```

Stores inherit from ancestor scopes by default. Pass `localOnly: true` when a
child subtree needs its own isolated copy.

---

## Step 4: Load Async Data Cleanly

Use `LxComputed.async` on your controller and `LStatusBuilder` in the UI.
Whenever an observed reactive input (like `query`) changes, `results`
re-fetches automatically and publishes loading, error, and success states:

```dart
class CatalogController extends LevitController {
  CatalogController(this.repository);
  final CatalogRepository repository;

  final query = ''.lx;
  late final LxAsyncComputed<List<Product>> results;

  @override
  void onInit() {
    super.onInit();
    results = LxComputed.async(() => repository.search(query()));
  }

  void setQuery(String value) => query.value = value;
}

class CatalogResults extends StatelessWidget {
  const CatalogResults({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<CatalogController>();
    return LStatusBuilder<List<Product>>(
      controller.results,
      onWaiting: (status) => status.hasLastValue
          ? ProductList(items: status.lastValue!) // Keep old data while refreshing
          : const CircularProgressIndicator(),
      onError: (status) => Text('Could not load: ${status.error}'),
      onSuccess: (items) => ProductList(items: items),
    );
  }
}
```

Need keyed caching, pagination, or cooperative cancellation? See
`LevitAsyncMap` in [Advanced Recipes](ADVANCED.md#2-caching-queries-refreshing-data-and-reconnecting-streams)
and [examples/async_catalog](../examples/async_catalog).

---

## Step 5: Test Your Feature

Both kits export `levit_testing.dart` with `LevitTestScope` so every test runs
in an isolated scope and fails if teardown throws:

```dart
import 'package:levit/levit_testing.dart';
import 'package:test/test.dart';

final counterStore = LevitStore((ref) => 0.lx);

void main() {
  setUpAll(Levit.enableAutoLinking);

  test('counter starts from overridden value', () {
    final harness = LevitTestScope(
      overrides: [counterStore.overrideWith((ref) => 10.lx)],
    );
    addTearDown(harness.close);

    final count = harness.run(() => counterStore.find());
    expect(count.value, 10);
    count.value++;
    expect(count.value, 11);
  });
}
```

For Flutter widget tests where you want to verify async unmount cleanup, pass a
`LevitScopeLifecycleController` to `LScope` and `await lifecycle.close()` after
unmounting:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_testing.dart';

testWidgets('unmounting disposes the session scope cleanly', (tester) async {
  Levit.enableAutoLinking();
  final lifecycle = LevitScopeLifecycleController();

  await tester.pumpWidget(
    MaterialApp(
      home: LScope(
        lifecycle: lifecycle,
        configure: (scope) => scope.put(() => SessionController()),
        child: const SessionView(),
      ),
    ),
  );

  await tester.pumpWidget(const SizedBox());
  await lifecycle.close();
});
```

---

## Using Levit in Pure Dart (CLI, Server, Shared Packages)

Outside Flutter, enable auto-linking once at startup and manage scope boundaries
with `Levit.runInScope` (short-lived jobs/requests) or `Levit.createScope`
(long-lived processes):

```dart
import 'package:levit/levit.dart';

Future<void> main() async {
  Levit.enableAutoLinking();

  // Short-lived scope (automatically disposed when the callback finishes):
  final greeting = await Levit.runInScope(() {
    Levit.put(() => GreetingService());
    return Levit.find<GreetingService>().hello('Levit');
  });

  // Long-lived scope (explicit awaited disposal):
  final appScope = Levit.createScope('server');
  try {
    appScope.put(() => DatabasePool());
    await startServer(appScope);
  } finally {
    await appScope.dispose();
  }
}
```

---

## Everyday Cheat Sheet

| What you want to do | Reach for |
| :-- | :-- |
| Register app-wide services at startup | Root `LScope(configure: ...)` + `Levit.enableAutoLinking()` |
| Create a controller owned by one screen | `LScopedView.put` |
| Share controllers/services across a feature | `LScope` + `context.levit.find<T>()` |
| Read an already-registered controller in a view | `LView` / `LAsyncView` |
| Rebuild only a small region on state changes | `LWatch` (implicit) or `LBuilder` (single reactive) |
| Render loading / error / success async state | `LStatusBuilder` |
| Show a dialog/sheet that needs page state | `showLevitDialog` / `showLevitModalBottomSheet` |
| Write isolated unit/widget tests | `LevitTestScope` (`levit_testing.dart`) |

---

## Where to Go Next

- **[Migrating from Riverpod, Bloc, or GetX](MIGRATING.md):** Side-by-side
  concept mapping, code translations, gotchas, and incremental adoption.
- **[Advanced Recipes](ADVANCED.md):** Explicit resource ownership with
  `own(...)` (Flutter controllers, timers, streams, non-auto-linked code),
  multi-step cancellable workflows (`LevitTaskGroup`), keyed caching
  (`LevitAsyncMap`), session/route scope switching, aliases, `ValueListenable`
  interop, and diagnostics.
- **[Why Levit](WHY_LEVIT.md):** Architectural rationale, tradeoffs, and when
  Levit is (or isn't) the right fit.
- **[Runnable Examples](../examples):** Complete reference apps
  (`task_board`, `async_catalog`, `route_scopes`, `scope_playground`,
  `nexus_studio`).
- **Optional Diagnostics & Developer Tooling:**
  - [levit_monitor](../packages/core/levit_monitor) — opt-in runtime telemetry and redaction.
  - [levit_devtools](../packages/tools/levit_devtools) — read-only Flutter DevTools extension (Scopes, Reactives, Tasks, Timeline, Diagnostics) over Dart VM Service.
  - [levit_lints](../packages/tools/levit_lints) — native Dart analyzer plugin (Dart 3.12+) catching lifecycle, ownership, redundant `LWatch`, and unscoped overlay mistakes in your IDE and CI.
  - [levit_mcp](../packages/tools/levit_mcp) — read-only MCP server for live runtime inspection by AI coding agents.
