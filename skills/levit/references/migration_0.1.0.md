# Migrating to Levit 0.1.0

Levit `0.1.0` is a coordinated breaking release (Dart 3.12+, Flutter 3.44+) with no compatibility aliases. Upgrade all Levit packages together.

## High-Impact Renames & Surface Changes

| Before | 0.1.0 Replacement |
| :--- | :--- |
| `autoDispose(res)` | `own(res)` (add `dispose:` callback for unknown types) |
| `Lx.*` / `Ls.*` in app kits | `Levit.*` (`Levit.batch`, `Levit.untracked`, `Levit.isBatching`, `Levit.currentScope`, `Levit.put`/`find`) |
| `count(5)` to write | `count.value = 5` (`call()` is read-only) |
| `.toBuilder` | Construct inside the registration builder |
| `.levitPut` / `.levitLazyPut` / `.levitLazyPutAsync` | Explicit `scope.put(...)` or `Levit.put(...)` |
| `LView.put` / `LAsyncView.put` | `LScopedView.put` / `LAsyncScopedView.put` |
| `initialized` | `isInitialized` |
| `computedValue` | `requireValue` |
| `runGuardedAsync(cancelOnClose:)` | `runGuardedAsync(discardResultOnClose:)` |
| `LevitQueryFamily<K, T>` | `LevitAsyncMap<K, T>` (`queries.entry(k)`, `await queries.refresh(k)`, `await queries.fetch(k)`) |
| `LxFamilyHandle<T, R>` | `LxResource<T, R>` (`resource.producer`, `await resource.refresh()`) |
| Plain value families | `map.entry(key)` or `list.entry(index)` |
| `LStatusBuilder` `onWaiting: () => ...` | `onWaiting: (status) => ...` |
| `LStatusBuilder` `onError: (e, st) => ...` | `onError: (status) => ...` (`status.error`, `status.stackTrace`) |
| `findStoreAsync` / `*.findAsync` | `findAsyncStore` / `findAsync` |
| `retries` / `retryDelay` / `useExponentialBackoff` | Explicit `LevitRetryPolicy` |
| `package:logger` `Level` in `levit_monitor` | `LevitLogLevel` |
| Unprefixed monitor transports/events | `Levit*` prefixed (`LevitConsoleTransport`, `LevitWebSocketTransport`, `LevitFileTransport`, `LevitMultiTransport`, `LevitMonitorEvent`, etc.) |
| Advanced task engine/groups/cache/middleware from default kit barrel | Import `package:levit_flutter/tasks.dart` or `package:levit/tasks.dart` |
| `levit_devtools` / `levit_devtools_ui` | Removed — use `levit_mcp` + `levit_lints` + `skills/levit` |

## Behavioral Contracts to Audit During Migration

1. **Awaited disposal:** `close()`, `delete()`, `reset()`, `scope.dispose()`, and `stop()` are async and must be awaited.
2. **Factories:** `isFactory: true` no longer implies `permanent: true`; release owned instances with `await scope.releaseFactoryInstance(...)`.
3. **Store lookup:** Inherits ancestor instances by default; pass `localOnly: true` for fresh local state. Install overrides via `scope.applyOverrides([store.overrideWith(...)])`.
4. **View re-resolution:** Changing a closure passed to `LView` / `LAsyncView` does not refetch; pass captured inputs in `args: [...]`.
5. **Tasks:** Task calls return `Future<T>` and signal cancellation/drop/supersession via typed exceptions rather than returning `null`.
6. **Optional DI lookup:** `findOrNull<T>()` only returns `null` when unregistered; construction/type failures now propagate.
