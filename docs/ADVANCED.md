# Advanced Levit patterns

Start with [scopes, owners, state and widgets](ONBOARDING.md). These patterns use
the same 0.1.0 ownership rules and the normal `levit` or `levit_flutter` kit.
Choose them for a concrete feature need; keep application policy in controllers
and stores.

Construct the controller examples through registration builders, such as
`scope.put(() => SelectionController())` or `LScopedView.put`. Registration
runs initialization and assigns the lifetime; do not call `onInit()` manually.

## Selection and time helpers

`LevitSelectionMixin<T>` owns its selection state when the controller initializes.
Use stable domain IDs for `T` so replacing loaded objects preserves selection
identity. Multi-selection is the default; override `allowMultiSelect` for a
single selection:

```dart
import 'package:levit/levit.dart';

class SelectionController extends LevitController
    with LevitSelectionMixin<String> {
  @override
  bool get allowMultiSelect => false;
}
```

Call `select`, `deselect`, `toggle` or `clearSelection` from application methods.
When the available items change, reconcile removed IDs according to your domain
rules. The mixin does not know which selections are still valid.

`LevitTimeMixin` owns debounce, throttle and interval timers, plus countdowns.
Timer IDs share a namespace within the controller. Debounce replaces the pending
callback; throttle runs immediately and ignores calls during its cooldown.
Their callbacks are synchronous: put async operations in managed tasks when
cancellation and draining matter.

```dart
import 'package:levit/levit.dart';

class CountdownController extends LevitController with LevitTimeMixin {
  late final LevitCountdown countdown;

  @override
  void onInit() {
    super.onInit();
    countdown = startCountdown(duration: const Duration(seconds: 30));
  }
}
```

`startCountdown` starts immediately and is owned by the mixin. `pause()` freezes
the precise remainder; `resume()` excludes paused time; `stop()` resets without
finishing; `start()` begins a fresh run. The clock is monotonic, so delayed ticks
catch up. App suspension does not automatically pause it. Control the countdown
through these methods rather than assigning `remaining.value`.

A standalone `LevitCountdown` starts idle. Register it with an owner or await its
`dispose()` yourself. See [countdown semantics](../packages/kits/levit_dart/README.md#advanced-elapsed-time-countdowns-010)
for timing and callback details.

## Computed dependencies and batching

Dynamic dependency tracking is the default. Use `staticDeps: true` only when
every execution reads the same reactive dependencies:

```dart
import 'package:levit/levit.dart';

class PriceController extends LevitController {
  late final quantity = own(1.lx);
  late final unitPrice = own(250.lx); // Minor currency units.
  late final total = own(
    LxComputed(() => quantity.value * unitPrice.value, staticDeps: true),
  );
}
```

Changing dependency values is fine; changing which dependencies are read is not.
Keep dynamic tracking for conditional branches, changing collection addresses,
or computations that reach into replaceable producers. Measure before opting
into a static graph. Numeric reactive helpers are conveniences; validation,
rounding and units still belong in application methods.

Use `Levit.batch` for a short synchronous group of state changes. `batchAsync`
extends notification coalescing across awaited work in the current async context.
Writes remain immediately readable, unrelated contexts remain independent, and
exceptions do not roll changes back. Await all work belonging to the batch;
detached work can outlive it. Prefer fetching data first, then committing related
state changes in a short synchronous batch inside the operation's managed lifetime.

## Stores, aliases and factories

Store definitions are stable recipes. Identity is the definition object plus
the optional variant tag; labels and result types do not determine identity.
A child lookup borrows an ancestor instance unless it has a local registration
or requests `localOnly: true`.

Install typed builder overrides before the first local resolution. The receiving
scope owns resources created by the override:

```dart
import 'package:levit/levit.dart';

final counterStore = LevitStore((ref) => ref.own(0.lx));

Future<void> main() async {
  final parent = Levit.createScope('parent');
  try {
    final inherited = counterStore.findIn(parent);
    final child = parent.createScope('child');
    child.applyOverrides([counterStore.overrideWith((ref) => ref.own(10.lx))]);

    final local = counterStore.findIn(child);
    print('${inherited.value}, ${local.value}'); // 0, 10
  } finally {
    await parent
        .dispose(); // Includes its owned child and both store instances.
  }
}
```

Use `ref.findStore` or `ref.findAsyncStore` to compose typed
stores. Override the matching variant tag when targeting a particular instance.
An optional DI lookup returns null only for absence; builder and type errors
still propagate.

`bindExisting<Port, Implementation>` creates a non-owning alias of a local
singleton registration. Register the concrete implementation first. Aliasing
does not create another lifetime or make a factory into a singleton.

With `isFactory: true`, the registering scope owns disposable results, including
async results arriving during removal. Await `scope.releaseFactoryInstance(value)`
for early release. Await deletion before replacing an instantiated registration.
See the [scope API guide](../packages/core/levit_scope/README.md) for registration
and alias contracts.

## Choose the async abstraction by its lifetime

| Need | API and responsibility |
| --- | --- |
| Observe a future or stream as waiting/success/error | Own an `LxFuture` or `LxStream` wrapper. A plain future does not provide an IO cancellation mechanism. |
| Derive async state from reactive inputs | Own `LxComputed.async`. The default `latest` policy can overlap executions and publishes only the latest result. `exhaustLatest` permits one running computation plus one coalesced trailing run. |
| Replace an owned producer while preserving the observer handle | Own `LxResource` and await `refresh()`. The resource drains the previous producer before replacement. |
| Load and refresh data by key | Own `LevitAsyncMap`; entries are observation handles. Keep mutation, pagination and optimistic-update policy in application code. |
| Coordinate cancellable work and its descendants | Use a task mixin and child groups. Await workflow completion and owner cleanup. |
| Discard a simple operation's result after owner closure | `runGuardedAsync` returns null after closure by default. It does not register, drain or cancel that operation. |

A guarded action can also succeed with null, and its errors still propagate.
Use task outcomes when callers need to distinguish successful nullable data
from cancellation or supersession.

`LxStreamCompletionPolicy.close` is the default. Choose `retain` when source
completion should preserve the wrapper's last state and allow an explicit later
restart. A retained wrapper still needs an owner. Use `status.hasLastValue` when
successful nullable data must be distinguished from no previous value.

Both task mixins expose a supervisor root. Workflow groups default to
`cancelOnError` and await descendant cleanup. Coordinate in group bodies; only
leaf tasks consume worker slots. Controller mixins default to 8 slots, while
the engine defaults to 256 pending submissions. Set `maxPending: null` only
when intentionally allowing an unbounded queue. Choose a conflict policy for
repeated logical IDs within a group.

Deadlines include queue time and inherit the earliest limit. Cancellation is
cooperative; connect it to the underlying IO and finish cleanup in `finally`.
`LevitRetryPolicy` requires an error classifier and caps its backoff. Successful
null values, failures, cancellation, dropping and supersession have distinct
outcomes. See [structured workflows](../packages/kits/levit_dart/README.md#structured-workflows-in-010)
and the [save/upload example](../examples/task_board/lib/save_upload.dart).

For isolate work, use `submitIsolate`, `scheduleIsolate` or `runIsolateTask` with
a top-level/static entrypoint and sendable arguments. These entrypoints bridge
group cancellation and progress and wait for isolate exit. Moving work to an
isolate does not make it a durable job across application restarts.

## Flutter interoperability and retained widgets

Create a `ValueListenable` adapter once at an owner boundary, then reuse it:

```dart
import 'package:levit_flutter/levit_flutter.dart';

class CounterAdapterController extends LevitController {
  late final count = own(0.lx);
  late final listenable = own(count.asValueListenable());
}
```

The adapter subscribes while it has listeners. Its disposal only detaches from
the source; the source owner must keep that state alive for the consumer's
lifetime. Avoid allocating adapters during every widget build.

`LKeepAlive` requests retention from an ancestor that supports automatic
keep-alive, such as the usual `ListView`/`PageView` child machinery. Retaining a
subtree also retains its scope and work. It neither survives removal from the
owning tree nor pauses background activity. Mount/unmount callbacks describe
widget lifetime, not viewport visibility. The
[Flutter kit example](../packages/kits/levit_flutter/example) includes a local
mount observer and countdown/listenable integration.

## Resource composition and replacement

A non-controller `LevitScopeDisposable` can mix in `LevitResourceOwnership` to
own resources with the same cleanup rules. Use `own(resource, dispose: ...)`
for third-party types without a supported disposable contract. There is no
method-name guessing. Delegate lifecycle hooks and await async cleanup.

For replacing a Flutter scope, keep one `LevitScopeLifecycleController` stable
while its scope widget is mounted. Replacement requests serialize and coalesce
to the latest configuration. Use `settled` plus `error` to inspect a transition,
`retry()` after a failure, and awaited `close()` to observe terminal cleanup
errors. An obsolete initializer cannot close a newer scope. The
[session example](../examples/scope_playground/lib/session_replacement.dart)
demonstrates the loading and retry UI.

## Diagnostics and ecosystem boundaries

`scope.describe()` returns immutable ancestry, registration and lifecycle
metadata without dependency values or raw tags. For runtime events, explicitly
attach [levit_monitor](../packages/core/levit_monitor) and await detachment after
application owners finish. Monitor attachment does not enable auto-linking.

Use `package:levit_monitor/levit_monitor.dart` for browser-compatible monitoring
and `levit_monitor_protocol.dart` for protocol/model consumers. File transport
requires the separate `levit_monitor_io.dart` entrypoint and an IO platform.

History and worker statistics are opt-in. Mark sensitive values at construction,
before their first event; custom attributes and names should not contain secrets.
Reconnect snapshots recover current state, while gaps or dropped events still
mean incomplete history. Task events reach the inspector through an explicit
[application adapter](../packages/core/levit_monitor/example/task_adapter.dart).

The lint plugin and inspector are currently private workspace tools; use the
checkout instructions in [onboarding](ONBOARDING.md#continue-from-a-working-feature).
Persistent storage, codecs, migrations, restoration and persistent task-result
caches belong to the independent [ecosystem roadmap](ecosystem_roadmap.md).
