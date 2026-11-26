# Reactive State & Flutter Bindings (Levit 0.1.0)

## Core Reactive Primitives

- **`LxVar<T>` (`0.lx`)**: Mutable reactive cell. Read via `v.value` or `v()`; write via `v.value = next`.
- **Collections**: `LxList<T>` (`<T>[].lx`), `LxMap<K, V>` (`<K, V>{}.lx`), `LxSet<T>` (`<T>{}.lx`).
- **Narrow observation**:
  - `map.entry(key)` / `list.entry(index)` borrow a single address without rebuilding on unrelated mutations (note: list entry tracks position, not item identity).
  - `.asReadable` exposes `LxReadable<T>` (observation-only without setters or disposal) on any `LxBase<T>` reactive (`LxVar`, `LxList`, `LxMap`, `LxSet`, `LxComputed`, etc.).
- **`LxComputed<T>`**: Synchronous derived state with automatic dependency tracking.
- **`LxComputed.async<T>`**: Async derived state producing `LxStatus<T>`. Supports `LxAsyncConcurrency.exhaustLatest` (one running + one coalesced trailing run).
- **`LxStream<T>`**: Reactive stream wrapper (`LxStream.defer` + `restartDeferred` + `completionPolicy: retain` preserves and rebinds completed or reconnectable sources).
- **`LxWorker`**: Side effects on reactive changes. Prefer `LxWorker.withContext` for cooperative cancellation (`latest` cancels superseded runs and drains `finally`).

## Batching & Untracked Reads (`Levit` Facade)

In kits (`levit` / `levit_flutter`), `Lx` and `Ls` are hidden — always use `Levit`:

```dart
Levit.batch(() {
  firstName.value = 'Ada';
  lastName.value = 'Lovelace';
});

await Levit.batchAsync(() async {
  // Context-local notification batching across async steps
  status.value = 'loading';
  data.value = await fetchData();
  status.value = 'ready';
});

final snapshot = Levit.untracked(() => count.value);
final active = Levit.isBatching;
```

## Flutter Reactive Widgets

- **`LWatch(() => Widget)`**: Implicitly tracks every reactive read inside its callback. Use for tight, localized rebuilds.
- **`LView` / `LScopedView` (`autoWatch`)**: Defaults to `autoWatch: true`. For small screens, read reactives directly in `buildView` and omit outer `LWatch`. For large screens, set `autoWatch: false` and place focused `LWatch` widgets around dynamic leaves.
- **`LBuilder` / `LSelectorBuilder`**: Explicit or selector-based rebuild boundaries.
- **`LStatusBuilder<T>`**: Renders `LxStatus<T>` (`LxIdle`, `LxWaiting`, `LxSuccess`, `LxError`):

```dart
LStatusBuilder<User>(
  controller.userStatus,
  onIdle: (status) => const Text('Ready'),
  onWaiting: (status) => const CircularProgressIndicator(),
  onError: (status) => Text('Error: ${status.error}'),
  onSuccess: (user) => Text(user.name),
)
```

- Check `status.hasLastValue` to distinguish "no prior data" from a successful `null`.
- Construct custom transitions with `.fromPrevious` or `.retained`.
- **Flutter `ValueListenable` interop**: `source.asValueListenable()` — retain/own the adapter outside `build`; disposing the adapter unsubscribes without closing `source`.
- **Kit helpers (`levit_flutter`)**: `LevitAppLifecycleMixin`, `LevitLoopLifecycleMixin`, `showLevitDialog`, `showLevitModalBottomSheet`.
