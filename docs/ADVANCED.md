# Advanced Levit Recipes

New to Levit? Start with [Getting Started](ONBOARDING.md) first.

Pick the recipe for the problem you're solving—you don't need to read this guide
top to bottom. Every recipe uses the standard kit import
(`package:levit/levit.dart` or `package:levit_flutter/levit_flutter.dart`), plus
`tasks.dart` when using advanced task orchestration types.

---

## 1. Coordinated Async Workflows, Retries & Double-Taps

**Use when:** A user action triggers multi-step async work (such as saving a
record and uploading attachments) that must prevent duplicate runs, retry
transient network errors, and cancel cleanly if the screen closes.

Add `LevitTasksMixin` to a controller when you need background scheduling and
cancellation, or `LevitReactiveTasksMixin` when your UI also needs reactive
`isBusy`, `totalProgress`, and `hasBlockingTasks` indicators:

```dart
import 'package:levit/levit.dart';
import 'package:levit/tasks.dart';

class UploadController extends LevitController with LevitReactiveTasksMixin {
  UploadController(this.repository);
  final UploadRepository repository;

  static final _retry = LevitRetryPolicy(
    maxRetries: 3,
    initialDelay: const Duration(milliseconds: 200),
    shouldRetry: (error, _) => error is TransientNetworkException,
  );

  Future<void> syncAll(List<Document> docs) async {
    // If any upload fails, sibling uploads are cancelled automatically and
    // every running upload's `finally` block finishes before runGroup returns.
    await taskGroup.runGroup((uploads) async {
      final futures = docs
          .map(
            (doc) => uploads.schedule(
              (task) => repository.upload(doc, cancelled: task.cancelled),
              id: doc.id,
              conflictPolicy: LevitTaskConflictPolicy.restart,
              retryPolicy: _retry,
            ),
          )
          .toList();
      await Future.wait(futures);
    }, name: 'document-sync');
  }
}
```

### Handling overlapping calls (`conflictPolicy`)

When two calls submit the same `id` inside the same group, `conflictPolicy`
controls what happens:

| Policy | What happens | Typical use |
| :-- | :-- | :-- |
| `reject` *(default)* | Fails the new call with `LevitTaskConflictException`. | Exclusive operations that shouldn't overlap. |
| `join` | Shares the result of the already-running call. | Two widgets requesting the same refresh. |
| `restart` | Cancels the running call and starts the new one. | Search-as-you-type or filter changes. |
| `coalesceLatest` | Lets the current call finish, then runs once more with the latest arguments. | Auto-saving after rapid edits. |
| `enqueue` | Queues every submission in FIFO order. | Ordered writes or mutations. |
| `drop` | Ignores the new call with `LevitTaskDroppedException`. | Preventing double-tap form submits. |

**How it behaves:**
- **Cooperative cancellation:** Dart `Future`s cannot be forcefully killed from
  outside, so pass `task.cancelled` to your HTTP/IO client or call
  `task.throwIfCancelled()` between steps, and release handles in `finally`.
  When the controller closes, Levit cancels all active tasks and waits for them
  to finish before closing your repositories or other owned resources.
- **Concurrency & deadlines:** A parent group can safely wait on child tasks
  without deadlocking the worker pool—only individual scheduled tasks use
  concurrency slots (default `8` at a time, up to `256` queued). If you set a
  deadline on a parent group, every child task inherits it.
- **CPU-heavy work in isolates:** Use `scheduleIsolate`, `submitIsolate`, or
  `runIsolateTask` with a top-level or static function (pass `group:` so
  cancelling the group stops the isolate and waits for it to exit).
- See [examples/task_board/lib/save_upload.dart](../examples/task_board/lib/save_upload.dart)
  for a complete working workflow.

---

## 2. Caching Queries, Refreshing Data, and Reconnecting Streams

In [Getting Started](ONBOARDING.md), `LxComputed.async` covered a single reactive
fetch. When your app needs more control over how async data is cached,
refreshed, or reconnected, pick the tool that matches your scenario:

| Scenario | Use | Why |
| :-- | :-- | :-- |
| Wrap one `Future` as loading/data/error | `LxFuture` | Simplest wrapper when inputs don't change (supports `restart(...)`). |
| Wrap or reconnect a live `Stream` / WebSocket | `LxStream` (`defer` + `restartDeferred`) | Lazy subscription, keeps listeners connected across reconnects, and supports `completionPolicy: retain`. |
| Auto-refetch whenever reactive state changes | `LxComputed.async` | Supports `latest` (ignore older runs), `exhaustLatest` (finish the current run, then run once more with the latest input), and `await computed.wait` for awaiting the next settled value. |
| Cache and refresh data per ID or search query | `LevitAsyncMap` | Keeps one cached entry per key, deduplicates concurrent fetches, and cleans up unused entries automatically. |

### Caching & refreshing by key (`LevitAsyncMap`)

**Use when:** A screen fetches data by key (a search string, user ID, or filter)
and you want automatic caching, pull-to-refresh, and stale-while-revalidate UI.

You give `LevitAsyncMap` a loader function once on your controller. After that:
- Watching `byQuery.entry(query)` in the UI automatically starts loading on
  first read and keeps the widget subscribed even across refreshes.
- Calling `await byQuery.fetch(query)` returns cached data if it is still fresh,
  or joins an already-running request for that key.
- Calling `await byQuery.refresh(query)` forces a fresh reload (great for
  pull-to-refresh) while keeping the previous list visible on screen.

```dart
class ProductsController extends LevitController with LevitTasksMixin {
  ProductsController(this.repo);
  final ProductRepository repo;

  late final byQuery = own(
    LevitAsyncMap<String, List<Product>>(
      (query, task) => repo.search(query, cancelled: task.cancelled),
      engine: taskEngine,
    ),
  );

  // Pull-to-refresh triggers a reload while keeping current items visible:
  Future<void> reload(String query) => byQuery.refresh(query);
}

// In Flutter — pass entry(query) directly to LStatusBuilder:
LStatusBuilder<List<Product>>(
  controller.byQuery.entry(query),
  onWaiting: (status) => status.hasLastValue
      ? ProductList(status.lastValue!) // Show previous results while refreshing
      : const CircularProgressIndicator(),
  onError: (status) => Text('Refresh failed: ${status.error}'),
  onSuccess: ProductList.new,
);
```

**How caching and memory cleanup work by default:**
- **Cache freshness (30s):** Calling `fetch(key)` within 30 seconds returns the
  cached value immediately without hitting the network again.
- **Automatic cleanup (30s / 128 entries):** Once no widget is watching a key,
  it stays in memory for 30 seconds in case the user navigates back, then gets
  evicted (up to 128 unused entries kept). Anything currently visible on screen
  or still loading is never evicted.
- **Nullable values:** Always check `status.hasLastValue` instead of
  `status.lastValue != null` if your loader can validly return `null`.

### Reconnecting a live stream without breaking listeners (`LxStream.defer`)

**Use when:** You have a live stream (like a WebSocket or chat feed) that needs
to disconnect and reconnect on demand—for example, after a network drop or auth
token refresh—without making every listening widget resubscribe.

Use `LxStream.defer` with `LxStreamCompletionPolicy.retain`, then call
`restartDeferred(...)` whenever you want to bind a fresh stream:

```dart
class FeedController extends LevitController {
  FeedController(this.socket);
  final SocketClient socket;

  late final LxStream<Event> feed;

  @override
  void onInit() {
    super.onInit();
    feed = LxStream<Event>.defer(
      () => socket.watchEvents(),
      completionPolicy: LxStreamCompletionPolicy.retain,
    );
  }

  void reconnect() {
    feed.restartDeferred(() => socket.watchEvents());
  }
}
```

- **Lazy & auto-linked:** Because `LxStream` is created in `onInit()`,
  auto-linking disposes it when `FeedController` closes, and the underlying
  stream only subscribes while something is listening.
- **Why `completionPolicy: retain`?** By default, an `LxStream` closes when its
  source stream ends. Setting `retain` keeps its last value visible so you can
  call `restartDeferred(...)` later to start a fresh run.

---

## 3. Async Scope Setup, Session Switching & Route Lifetimes

**Use when:** Switching a logged-in user, workspace, or route parameter must
finish tearing down the old scope (and its connections/controllers) completely
before initializing the next one.

Attach a stable `LevitScopeLifecycleController` to `LAsyncScope` (or `LScope`)
to render loading/error states, retry failed setup, and await cleanup in tests:

```dart
class SessionHost extends StatefulWidget {
  const SessionHost({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<SessionHost> {
  final lifecycle = LevitScopeLifecycleController();

  @override
  Widget build(BuildContext context) {
    return LAsyncScope(
      lifecycle: lifecycle,
      args: [widget.sessionId], // Changing args closes the old scope before opening the new one
      configure: (scope) async {
        final conn = await SessionConnection.open(widget.sessionId);
        scope.put(() => conn);
      },
      loading: (_) => const Center(child: CircularProgressIndicator()),
      error: (_, error) => TextButton(
        onPressed: lifecycle.retry,
        child: Text('Retry ($error)'),
      ),
      child: const SessionBody(),
    );
  }
}
```

**How it behaves:**
- **Fast switches skip stale work:** If `sessionId` changes `A → B → C` while
  `A` is still shutting down, Levit finishes closing `A`, skips `B`, and opens
  `C` directly—stale work from `A` can never accidentally close `C`.
- **Route-tied lifetimes (`LRouteScope` / `LAsyncRouteScope`):** Use these
  instead of `LScope` when a `Navigator` route owns the state and you want to
  react when another screen covers or uncovers this route via
  `LRouteScope.visibilityOf(context)` (for example, pausing video playback or
  refreshing data on return).
- See [examples/scope_playground/lib/session_replacement.dart](../examples/scope_playground/lib/session_replacement.dart).

---

## 4. Scoped Overrides, Interface Aliases & Factories

### Overriding a `LevitStore` for a subtree or test

**Use when:** A feature subtree, preview mode, or test should swap out a
`LevitStore` without affecting the rest of the app.

Install overrides before the store is first read in that scope—the child scope
owns the overridden value and cleans it up when it closes:

```dart
final counterStore = LevitStore((ref) => ref.own(0.lx));

final child = parent.createScope('feature');
child.applyOverrides([
  counterStore.overrideWith((ref) => ref.own(10.lx)),
]);

final parentCount = counterStore.findIn(parent); // 0
final childCount = counterStore.findIn(child);   // 10
```

Inside a store builder, resolve other stores with `ref.findStore` /
`ref.findAsyncStore` and register async cleanup callbacks with `ref.onDispose`.

### Exposing multiple interfaces for one singleton (`bindExisting`)

**Use when:** One concrete class implements separate read/write interfaces and
both should resolve to the exact same instance.

Register the concrete class once, then point each interface to it with
`bindExisting`:

```dart
scope.put(() => UserRepository());
scope.bindExisting<UserReader, UserRepository>();
scope.bindExisting<UserWriter, UserRepository>();
```

Both interfaces return the same `UserRepository`, and disposal still runs only
once when `UserRepository` (or its scope) is closed.

### Creating a fresh instance per lookup (`isFactory: true`)

**Use when:** Every `find()` call needs a new instance (such as a per-request
helper or disposable form session) rather than a shared singleton:

```dart
scope.lazyPut(() => RequestSession(), isFactory: true);
```

Levit still tracks every disposable instance created by that factory and closes
them automatically when the scope disposes. To release one instance early, call
`await scope.releaseFactoryInstance(instance)`.

---

## 5. Explicit Resource Ownership (`own`), Custom Owners & `onBeforeClose`

### When to use `own(...)`

With `Levit.enableAutoLinking()` enabled, reactive values (`0.lx`, `LxComputed`,
`LxWorker`, etc.) created during controller construction or `onInit()` are
disposed automatically. Reach for `own(...)` (or `ref.own(...)` in `LevitStore`)
whenever auto-linking cannot capture a resource:

1. **Non-reactive resources** — Flutter objects (`TextEditingController`,
   `ScrollController`), `StreamSubscription`, `Timer`, `Sink`, `LevitAsyncMap`,
   or custom `LevitDisposable` objects.
2. **Lazily or dynamically created reactives** — `late final x = ...` fields
   evaluated after `onInit()`, or reactives allocated later inside event
   handlers.
3. **Pure Dart code running without `Levit.enableAutoLinking()`**.

```dart
class SearchController extends LevitController {
  // Flutter & third-party objects take an explicit dispose callback:
  late final textController = own(
    TextEditingController(),
    dispose: (c) => c.dispose(),
  );

  // Built-in adapters handle StreamSubscription, Timer, Sink, and reactives:
  late final pollTimer = own(
    Timer.periodic(const Duration(seconds: 30), (_) => refresh()),
  );

  // Lazy reactive fields initialized on first read should be wrapped in own():
  late final filter = own(''.lx);

  void refresh() {}
}
```

### Choosing between `LevitController` and `LevitDisposable`

- **Need `own(...)`, auto-linking, `onBeforeClose`, monitoring identity, or
  task/time/loop mixins?** Extend `LevitController`—even for non-UI services or
  repositories (it is pure Dart with no Flutter dependency).
- **Only need one cleanup method (or extending a third-party base class)?**
  Implement `LevitDisposable` so the owning scope awaits your `dispose()`
  method automatically:

```dart
final class DatabasePool implements LevitDisposable {
  DatabasePool(this._connection);
  final Connection _connection;

  @override
  Future<void> dispose() => _connection.close();
}
```

### Flushing work before owned resources close (`onBeforeClose`)

**Use when:** Your controller needs to flush buffered analytics or send a last
API call *while its repository and other owned resources are still open*. Always
await `super.onBeforeClose()`:

```dart
@override
Future<void> onBeforeClose() async {
  await super.onBeforeClose();
  await flushBufferedEvents();
}
```

---

## 6. Flutter Interop & Built-In Controller Mixins

### Bridging to `ValueListenable<T>` (`asValueListenable`)

**Use when:** A Flutter widget or third-party package only accepts a
`ValueListenable<T>` (such as `ValueListenableBuilder`, animations, or map
controllers). Create the adapter once on your controller—never inside `build()`:

```dart
class CounterController extends LevitController {
  final count = 0.lx;
  late final listenable = own(count.asValueListenable());
}

ValueListenableBuilder<int>(
  valueListenable: controller.listenable,
  builder: (_, value, __) => Text('$value'),
);
```

The adapter subscribes only while Flutter widgets are listening, and disposing
the adapter unsubscribes without closing `count`.

### Debouncing, throttling & countdowns (`LevitTimeMixin`)

**Use when:** You want search-input debouncing, button throttling, or a
pause/resume countdown timer that cancels automatically when the controller
closes:

```dart
class QuizController extends LevitController with LevitTimeMixin {
  late final LevitCountdown timer;

  @override
  void onInit() {
    super.onInit();
    timer = startCountdown(
      duration: const Duration(seconds: 30),
      onFinish: submitAnswers,
    );
  }

  void onSearchChanged(String text) {
    debounce('search', const Duration(milliseconds: 300), () {
      runSearch(text);
    });
  }
}
```

Control the countdown with `timer.pause()`, `resume()`, `stop()`, and `start()`.
Countdown and timer callbacks are synchronous; launch async work through
`LevitTasksMixin`. See
[countdown semantics](../packages/kits/levit_dart/README.md#elapsed-time-countdowns).

### Selection state & managed background loops

- **`LevitSelectionMixin<T>`:** Use when a list or grid needs single- or
  multi-selection tracked by stable item IDs (`select`, `deselect`, `toggle`,
  `clearSelection`; override `allowMultiSelect => false` for single selection).
- **`LevitLoopMixin` / `LevitLoopLifecycleMixin`:** Use when a controller runs a
  periodic polling loop or continuous background worker tied to its lifecycle
  (and optionally paused when the Flutter app goes to the background). Always
  await `stopService` / `dispose` so the active iteration finishes cleanly.

---

## 7. Performance Tuning (When Needed)

Levit's defaults are fast enough for most apps. Reach for these tools only when
profiling shows a specific hotspot:

- **Updating several fields at once?** Wrap the writes in `Levit.batch(() { ... })`
  (or `Levit.batchAsync` across awaits) so dependent widgets rebuild once
  instead of once per write. Note that `batchAsync` only groups notifications
  for the current async flow—it does not roll back writes if an error occurs.
- **Large map or list rebuilding too many rows?** Observe a single item with
  `map.entry(key)` or `list.entry(index)` so row #42 rebuilds only when item #42
  changes.
- **Tight hot-path computed with fixed inputs?** Pass `staticDeps: true` to
  `LxComputed` *only* when every evaluation reads the exact same fields (no `if`
  branches skipping a read):

```dart
final quantity = 1.lx;
final unitPrice = 250.lx;
late final total = own(
  LxComputed(() => quantity.value * unitPrice.value, staticDeps: true),
);
```

---

## 8. Runtime Observability & Diagnostics

**Use when:** You want to inspect which scopes and controllers are currently
alive, log reactive changes with sensitive fields redacted, or stream live
runtime state to an AI coding agent.

Add `levit_monitor` separately (it is opt-in and never bundled into `levit` or
`levit_flutter`):

```dart
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';

Future<void> main() async {
  Levit.enableAutoLinking(); // Monitoring never enables auto-linking implicitly.
  await LevitMonitor.attach(transport: LevitConsoleTransport());
}
```

- **Redact secrets from the start:** Mark sensitive values at construction
  (`LxVar(token, isSensitive: true)`) so even the initial creation event is
  redacted before logging or buffering.
- **Lightweight snapshots without `levit_monitor`:** Call `scope.describe()`
  anywhere to get a read-only snapshot of scope ancestry, registrations, and
  cleanup progress without exposing values.
- **Web vs. IO imports:** `package:levit_monitor/levit_monitor.dart` works on
  all platforms including Web; import `package:levit_monitor/levit_monitor_io.dart`
  for `LevitFileTransport`.
- **Optional developer tooling:**
  - [levit_devtools](../packages/tools/levit_devtools) — read-only Flutter DevTools extension
    streaming redacted scopes, reactives, tasks, timeline, and diagnostics over
    Dart VM Service (`await LevitDevTools.attach()`).
  - [levit_lints](../packages/tools/levit_lints) — native Dart analyzer plugin (Dart 3.12+) that
    flags missing `super` lifecycle calls, unowned resources, discarded Levit
    futures, global `Levit.find` inside widgets, redundant outer `LWatch`, and
    unscoped raw overlays.
  - [levit_mcp](../packages/tools/levit_mcp) — read-only MCP server over
    authenticated loopback WebSockets for live runtime inspection by AI agents.
- **Storage boundary:** Persistence codecs, storage adapters, and persistent
  task caches are intentionally kept outside core runtime dependencies.
