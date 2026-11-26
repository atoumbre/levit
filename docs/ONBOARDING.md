# Start with the lifetime

This guide describes the current 0.1.0 API in this repository. Levit requires
Dart 3.12+; Flutter applications require Flutter 3.44+.

| Application | Import |
| --- | --- |
| Pure Dart | `package:levit/levit.dart` |
| Flutter | `package:levit_flutter/levit_flutter.dart` |

Use one kit for application code. Core packages are available for custom
integrations. To run this repository's examples, first follow the
[workspace setup](../CONTRIBUTING.md#development-setup).

## 1. Choose who owns the state

Choose an app, route, feature, subtree or test lifetime before registering a
dependency. A scope searches its own registrations, then its ancestors. It owns
local registrations and borrows inherited ones.

| Need | Starting point |
| --- | --- |
| One Flutter feature owns a controller and its view | `LScopedView.put` |
| Several widgets share a subtree's dependencies | `LScope`, or `LAsyncScope` for awaited setup |
| A view consumes an existing dependency | `LView` or `LAsyncView` |
| Dependencies follow route identity | `LRouteScope` or `LAsyncRouteScope` |
| A short Dart operation needs scoped dependencies | `Levit.runInScope` |
| A longer Dart lifetime needs explicit cleanup | `Levit.createScope` and awaited `scope.dispose()` |

Construct dependencies inside registration builders. In widgets, resolve them
with `context.levit.find<T>()` so nested scopes are respected. A child must not
dispose a dependency borrowed from its parent. `permanent: true` only protects
against a non-forced reset; disposing the owning scope still closes it.

## 2. Build a small Flutter feature

With `levit_flutter` in the application's dependencies, this is a complete
`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class CounterController extends LevitController {
  final count = 0.lx;

  void increment() => count.value++;
}

void main() {
  Levit.enableAutoLinking();
  runApp(
    MaterialApp(
      home: LScopedView<CounterController>.put(
        () => CounterController(),
        autoWatch: false,
        builder: (context, counter) => Scaffold(
          appBar: AppBar(title: const Text('Counter')),
          body: Center(child: LWatch(() => Text('${counter.count.value}'))),
          floatingActionButton: FloatingActionButton(
            onPressed: counter.increment,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ),
  );
}
```

The scoped view creates and owns the controller. The controller owns its state;
`increment` contains the mutation. `.value` writes, while `count()` and
`count.value` read. `LWatch` observes reads inside its callback and rebuilds that
region when they change.

Calling `Levit.enableAutoLinking()` before `runApp` automatically links reactive
fields created during owner construction to that controller's lifecycle. In pure
Dart without auto-linking—or for non-reactive resources and workers created
later—register them explicitly with `own(...)`. For a Flutter object such as
`TextEditingController`, pass an explicit disposer:
`late final input = own(TextEditingController(), dispose: (c) => c.dispose());`.

For a small view, leave `autoWatch: true` and read reactive values directly in
its builder. Use `autoWatch: false` with focused `LWatch` regions for larger
screens. Keep business logic in controllers or stores.

## 3. Share state deliberately

Use `LevitStore((ref) => ref.own(0.lx))` for a reusable state recipe. Keep the
definition stable, typically as a top-level `final`. `context.levit.findStore`
resolves it in Flutter; `store.findIn(scope)` resolves it in an explicit scope.
Store identity is the definition object plus its optional variant tag.

A lookup reuses an ancestor instance by default. Use `localOnly: true` when the
child needs its own state. Install `store.overrideWith(builder)` through
`scope.applyOverrides` before the first local resolution. Override resources
belong to the receiving scope. See [store composition](ADVANCED.md#stores-aliases-and-factories)
for an example.

Consuming `LView` and `LAsyncView` resolve initially, when their scope changes,
or when explicit `args` change. A new resolver closure alone does not refetch.
Pass captured inputs in `args`, such as `args: [userId]`. On owning scopes/views,
changing ownership arguments recreates the scope and awaits the previous cleanup.

For finer state boundaries, use:

- `LxComputed` for derived values and `LxReadable<T>` for observation-only consumers.
- `map.entry(key)` or `list.entry(index)` to observe one address. A list entry
  follows a position, so use stable keyed state when item identity matters.
- `LxResource` for an owned, replaceable reactive producer.
- `LevitAsyncMap` for task-backed loading by key. Give widgets `queries.entry(key)`
  and await `queries.refresh(key)` for the load result.

Use `LStatusBuilder` for waiting, success, and error states. A successful `null`
is valid data; `status.hasLastValue` distinguishes it from absent data:

```dart
class CatalogController extends LevitController with LevitTasksMixin {
  CatalogController(this.repository);
  final CatalogRepository repository;

  late final queries = own(
    LevitAsyncMap<String, List<Item>>(
      (query, task) => repository.search(query, cancelled: task.cancelled),
      engine: taskEngine,
    ),
  );
}

class CatalogResults extends StatelessWidget {
  const CatalogResults({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final controller = context.levit.find<CatalogController>();
    return LStatusBuilder<List<Item>>(
      controller.queries.entry(query),
      onWaiting: (status) => status.hasLastValue
          ? ItemList(items: status.lastValue!)
          : const CircularProgressIndicator(),
      onError: (status) => Text('Failed: ${status.error}'),
      onSuccess: (items) => ItemList(items: items),
    );
  }
}
```

The [async catalog](../examples/async_catalog) demonstrates pagination, retained
data during refresh, optimistic updates, and rollback.

## 4. Keep async work inside its lifetime

For controller-owned work, use `LevitTasksMixin` or `LevitReactiveTasksMixin`
when widgets also need reactive task details. Start workflows through
`taskGroup.runGroup` and submit leaf work from the group body. Workflow groups
cancel siblings on failure; the controller root supervises unrelated work.

Cancellation is cooperative: the IO adapter must stop its real operation and
finish cleanup. Owner shutdown requests cancellation, drains tracked work
including `finally` blocks, then releases remaining resources in reverse order.
Await cleanup to observe aggregated failures. An arbitrary unawaited future is
not automatically tracked, and a caller timeout does not finish owner cleanup.

Delegate lifecycle overrides to `super`: call `super.onInit()` and await async
`super.onBeforeClose()` / `super.onClose()` calls. Request cancellation from a
task; await disposal from outside that owner's running work. The
[save/upload example](../examples/task_board/lib/save_upload.dart) shows the full
workflow and repository lifetime.

For a short pure Dart operation, scope cleanup can be automatic and awaited:

```dart
import 'package:levit/levit.dart';

final counterStore = LevitStore((ref) => ref.own(0.lx));

Future<void> main() async {
  final result = await Levit.runInScope(() {
    final count = counterStore.find();
    count.value++;
    return count.value;
  });
  print(result); // 1; the scoped state has already been released.
}
```

For longer Dart lifetimes, create an explicit scope and await its disposal in
`finally`. In ordinary Flutter code, let scope widgets manage that boundary.

## 5. Test ownership and cleanup

The testing entrypoints provide `LevitTestScope` for isolated setup, typed
overrides, explicit future tracking and awaited teardown. A complete Dart test:

```dart
import 'package:levit/levit_testing.dart';
import 'package:test/test.dart';

final counterStore = LevitStore((ref) => ref.own(0.lx));

void main() {
  test('a local store override supplies the initial counter value', () {
    final harness = LevitTestScope(
      overrides: [counterStore.overrideWith((ref) => ref.own(10.lx))],
    );
    addTearDown(harness.close);

    final count = harness.run(() => counterStore.find());
    expect(count.value, 10);
    count.value++;
    expect(count.value, 11);
  });
}
```

Use `harness.track(operation)` for asynchronous work the harness must observe,
and await `harness.settle()` when the assertion requires its completion. Flutter
tests can import `package:levit_flutter/levit_testing.dart`.

Widget unmount starts cleanup synchronously. To await its result and surface
cleanup errors in widget tests, pass a stable `LevitScopeLifecycleController` to
`LScope`/`LAsyncScope`, unmount, and await `lifecycle.close()`:

```dart
testWidgets('unmount awaits scope cleanup', (tester) async {
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

Advance the test's fake clock when cleanup intentionally uses timers. `closed`
signals completion; `close()` also propagates cleanup errors. The
[session replacement tests](../examples/scope_playground/test/session_replacement_test.dart)
exercise loading, rapid changes, retry, and store overrides.

## Continue from a working feature

Use [advanced helpers](ADVANCED.md) when a feature needs explicit scheduling,
interoperability, or additional resource composition. See
[Why Levit](WHY_LEVIT.md) for architecture tradeoffs, and package READMEs plus
inline DartDoc for individual API contracts.

[levit_monitor](../packages/core/levit_monitor) adds optional runtime diagnostics.
For workspace tooling (currently private to this repository), see:

- [levit_lints](../packages/tools/levit_lints) — native Dart analyzer rules for lifecycle and reactive safety.
- [levit_mcp](../packages/tools/levit_mcp) — read-only MCP server for live runtime inspection by AI agents (`dart run levit_mcp`).
- [skills/levit](../skills/levit/SKILL.md) — portable Agent Skill encoding Levit idioms and best practices.

See [diagnostic boundaries](ADVANCED.md#diagnostics-and-ecosystem-boundaries) before
attaching telemetry.
