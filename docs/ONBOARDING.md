# Start with the lifetime

Levit 0.1.0 requires Dart 3.12+; Flutter applications require Flutter 3.44+.
Use `package:levit/levit.dart` in Dart and
`package:levit_flutter/levit_flutter.dart` in Flutter. The core packages support
custom integrations; applications generally need one kit import.

## 1. Scopes define the boundary

Choose an app, route, feature, subtree or test lifetime before registering state.
A scope resolves its own registrations first, then its ancestors. A child owns
what it creates and borrows what it inherits. Register inside builders so
construction and initialization are captured together.

```dart
final feature = Levit.createScope('editor');
try {
  final editor = feature.put(() => EditorController());
  await editor.save();
} finally {
  await feature.dispose();
}
```

In Flutter, use `LScope`/`LAsyncScope` for subtree ownership or `LScopedView.put`
for a controller and its view. `LView` consumes an existing registration. Resolve
inside widgets using `context.levit.find<T>()` so nested scopes work correctly.

## 2. Owners keep dependencies alive until work finishes

A controller owns its reactives, subscriptions and tasks. `own` accepts supported
resource contracts, or an explicit disposer for other resources:

```dart
late final text = own(TextEditingController(), dispose: (value) => value.dispose());
```

Call `Levit.enableAutoLinking()` before `runApp` to capture reactive construction.
Explicitly own workers and resources created later. Pure Dart applications can
use explicit ownership throughout.

Cleanup first requests cancellation and drains tracked work, including `finally`
blocks, then releases remaining owned resources in reverse order. Await cleanup
to receive aggregate failures after all attempts. A cancellation request or a
caller timeout is not cleanup completion. Delegate async lifecycle hooks with
`await super.onBeforeClose()` (or return the future).

Workflow groups cancel siblings on failure; the controller root supervises
unrelated workflows. Submit leaf work from group bodies. Never await the owner's
disposal inside its own task. See the runnable
[save/upload example](../examples/task_board/lib/save_upload.dart).

## 3. State belongs to an owner

Use `.lx` for mutable values, `LxComputed` for derivations, and `LxReadable<T>` for
observation-only consumers. Calls read; `.value` writes. Stores are stable recipe
objects, keyed by definition identity and variant, not by diagnostic names or
result types. Install `overrideWith` recipes before first local resolution.

Observe one key or position with `map.entry(key)` or `list.entry(index)`.
Own an `LxResource` to keep mounted consumers subscribed while replacing a
producer. Own a `LevitAsyncMap` for loading by key; give builders
`queries.entry(key)` and await `queries.refresh(key)` for the load result.
`status.hasLastValue` distinguishes absent data from a successful `null`.

[Searchable pagination](../examples/async_catalog) includes refresh and optimistic
rollback. Keep request and mutation policy in controllers/application code.

## 4. Widgets observe focused state

```dart
void main() {
  Levit.enableAutoLinking();
  runApp(MaterialApp(home: LScopedView<CounterController>.put(
    () => CounterController(),
    autoWatch: false,
    builder: (context, counter) => Scaffold(
      body: Center(child: LWatch(() => Text('${counter.count.value}'))),
      floatingActionButton: FloatingActionButton(
        onPressed: counter.increment,
        child: const Icon(Icons.add),
      ),
    ),
  )));
}
```

With the default `autoWatch: true`, read reactives directly in a small view's
builder. For a large screen, use focused `LWatch` regions as above. Keep business
logic in the controller. Use `LStatusBuilder` for full waiting/error statuses and
`asValueListenable()` when borrowing state into Flutter APIs. Own that adapter;
its disposal only unsubscribes.

## Test the boundary, then inspect it

Import `levit/levit_testing.dart` or `levit_flutter/levit_testing.dart` in tests.
`LevitTestScope` provides isolated setup, typed overrides, explicit task tracking
and awaited teardown with failure reporting. Widget unmount is synchronous;
retain a `LevitScopeLifecycleController` and await `close()` to observe cleanup
failures. `closed` is only a completion signal. Test code must advance its fake
clock when intentionally delayed cleanup is pending.

The [session replacement example and widget tests](../examples/scope_playground)
show cleanup, rapid changes, loading/retry and store overrides. Keep the lifecycle
controller stable while mounted; obsolete initialization affects only its own
generation.

Enable [levit_lints](../packages/tools/levit_lints) for focused static diagnostics.
For runtime inspection, opt into [levit_monitor](../packages/core/levit_monitor)
and run [levit_devtools](../packages/tools/levit_devtools). Telemetry/history are
optional, bounded and redacted. Reconnect snapshots describe current state,
not a complete missing event history.

Continue with [advanced helpers](ADVANCED.md), the
[cumulative migration guide](../MIGRATION_0.1.0.md), and inline DartDoc.
Storage, schema migrations and persistence integrations live on the independent
[ecosystem roadmap](../reports/ecosystem_roadmap.md).
