---
name: levit
description: Build, refactor, debug, test, and migrate Dart and Flutter applications using the Levit 0.1.0 reactive state, scoped dependency injection, structured tasks, lints, and levit_mcp runtime inspection framework. Use whenever the project depends on levit, levit_flutter, levit_dart, levit_scope, levit_reactive, or levit_monitor.
---

# Levit 0.1.0 Development Guide

Levit is an ownership-first reactive and dependency-injection runtime for Dart 3.12+ and Flutter 3.44+:

```text
scope (lifetime) -> controller / store (owner) -> reactive state -> Flutter bindings
```

## Non-Negotiable Core Rules

1. **Identify the lifetime boundary first** (app, route, feature, subtree, or test) before choosing a scope or registering a dependency.
2. **Import kits, not core packages** in application code:
   - Flutter apps: `package:levit_flutter/levit_flutter.dart`
   - Pure Dart apps: `package:levit/levit.dart`
   - Advanced task engines/groups/cache/middleware (opt-in): `package:levit_flutter/tasks.dart` or `package:levit/tasks.dart`
3. **Bootstrap Flutter auto-linking once:** Call `Levit.enableAutoLinking();` in `main()` before `runApp(...)`. Still call `own(...)` explicitly for non-reactive resources (timers, streams, `TextEditingController`) and any reactive created outside controller initialization.
4. **Resolve via `context.levit.find<T>()` in Flutter widgets** — never bare `Levit.find<T>()` when an `LScope` or `LScopedView` is in the widget tree.
5. **Read with `.value` or `call()`, write only with `.value`:** `count()` and `count.value` both read; `count.value = next` writes.
6. **Always `await` lifecycle teardown:** `await scope.dispose()`, `await Levit.delete<T>()`, `await Levit.reset()`, `await rx.close()`, and `await controller.stopService(id)`. Always call `super.onInit()`, `super.onBeforeClose()`, and `super.onClose()` in overrides.
7. **Keep widgets thin:** Business logic, side effects, and state mutations live in `LevitController` or `LevitStore`. Use `LWatch` for focused reactive rebuilds (and never wrap an entire `LView`/`LScopedView` body in `LWatch` when `autoWatch: true`).

## Choosing the Right Primitive

| Need | Use |
| :--- | :--- |
| One Flutter feature owns a controller + view | `LScopedView.put(() => MyController(), ...)` |
| Subtree shares multiple dependencies | `LScope` (or `LAsyncScope` for async setup) |
| View consumes an existing scoped dependency | `LView` or `LAsyncView` |
| Dependencies tied to route lifecycle | `LRouteScope` or `LAsyncRouteScope` |
| Dialog / bottom sheet inheriting caller's scope | `showLevitDialog` / `showLevitModalBottomSheet` (or `LScope.capture`) |
| Portable, overridable per-scope state recipe | `LevitStore` / `LevitAsyncStore` + `context.levit.findStore` |
| Pure Dart short-lived scope / unit test | `await Levit.runInScope(() async { ... })` |
| Pure Dart long-lived scope | `final s = Levit.createScope(); ... await s.dispose();` |
| Mutable reactive value / collection | `0.lx`, `<T>[].lx`, `<K, V>{}.lx`, `<T>{}.lx` |
| Derived synchronous / async state | `LxComputed(() => ...)` / `LxComputed.async(() async => ...)` |
| Single keyed entry without rebuilding whole collection | `map.entry(key)` / `list.entry(index)` |
| Owned replaceable reactive producer | `LxResource(() => createProducer())` |
| Keyed task-backed async loading | `LevitAsyncMap<K, T>` + `LStatusBuilder(queries.entry(k), ...)` |
| Side effects reacting to state changes | `own(LxWorker(source, (value) async { ... }))` |
| Controller task orchestration / retries / isolates | `LevitReactiveTasksMixin` / `LevitTasksMixin` |

## Minimal Idiomatic Flutter Feature

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class CounterController extends LevitController {
  final count = 0.lx.named('count');
  late final doubled = LxComputed(() => count.value * 2).named('doubled');

  @override
  void onInit() {
    super.onInit();
    own(count);
    own(doubled);
  }

  void increment() => count.value++;
}

void main() {
  Levit.enableAutoLinking();
  runApp(
    MaterialApp(
      home: LScopedView<CounterController>.put(
        () => CounterController(),
        autoWatch: false,
        builder: (context, controller) => Scaffold(
          body: Center(
            child: LWatch(
              () => Text('${controller.count.value} (x2: ${controller.doubled.value})'),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: controller.increment,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ),
  );
}
```

## Anti-Patterns to Avoid

- Putting feature/screen state in the root/global scope.
- Calling `Levit.find<T>()` inside widgets instead of `context.levit.find<T>()`.
- Importing `Lx` or `Ls` directly (hidden in kits; use `Levit.*` facade methods instead).
- Wrapping an entire `LView` / `LScopedView` return tree in `LWatch` when `autoWatch: true`.
- Mutating state or performing async work directly inside `build`.
- Creating imperative dialogs/sheets without `showLevitDialog` / `showLevitModalBottomSheet` / `LScope.capture`.
- Replacing an instantiated registration without first `await`ing `delete`.
- Forgetting `dispose:` adapter when calling `own(...)` on non-Levit objects (e.g., `own(TextEditingController(), dispose: (c) => c.dispose())`).

## Deep-Dive References

Load the matching reference file when working on a specific area:

- **Scopes, DI, Stores, Overrides & Flutter Scope Widgets:** Read `references/scopes_and_di.md`
- **Reactive State, Collections, Computed, Workers & Status UI:** Read `references/reactive_state.md`
- **Structured Tasks, Retries, Isolates, Loops & `tasks.dart`:** Read `references/tasks_and_loops.md`
- **Testing Patterns & `levit_lints` Analyzer Rules:** Read `references/testing_and_lints.md`
- **Live Debugging with `levit_monitor` + `levit_mcp`:** Read `references/monitoring_and_mcp.md`
- **Migrating Existing Apps to Levit 0.1.0:** Read `references/migration_0.1.0.md`
