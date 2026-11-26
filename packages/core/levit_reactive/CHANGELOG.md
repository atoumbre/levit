## 0.1.0

- **Breaking:** Requires Dart 3.7+.
- **Breaking:** Reactive `close()` now returns `Future<void>`, drains admitted work and subscriptions, and aggregates cleanup failures in `LxCleanupException`.
- **Breaking:** Replace `LxFamily` with borrowing map/list entries (`entry(...)`); keyed async caching lives in `LevitAsyncMap` (`levit_dart` / `levit`).
- Add `LxWorker.withContext` for cooperative cancellation (`isCancelled`, `cancelled`, `throwIfCancelled`).
- Add `LxReadable<T>` observation-only interface and `asReadable` across reactive values (`LxBase<T>`), replacing `LxState<T>`.
- Define `LxBool`, `LxInt`, and `LxDouble` as type aliases of `LxVar<bool|int|double>` with typed helper extensions (`LxBoolOperations`, `LxIntOperations`, `LxDoubleOperations`), and standardize named `{initial, name, isSensitive}` parameters on `LxList`, `LxMap`, and `LxSet` (and `.from(...)` factories).
- Add `LxStatus.hasLastValue`, `.fromPrevious(...)`, `.retained(...)`, `when(...)`, and `maybeWhen(...)` (on both `LxStatus<T>` and `LxReadable<LxStatus<T>>`) to preserve nullable retained values and pattern-match async states cleanly.
- Reconnect static computed dependencies, including asynchronous reads, when observation resumes.
- Default `Lx.enableWatchMonitoring` off and add optional `LevitReactiveMetadataObserver` for name, owner, and sensitivity changes.

## 0.0.12

- **Breaking:** reactive `call()` only reads; assign through `.value`.
- Isolate asynchronous batch notification queues by execution context, including nested batches and history middleware.
- Updated internal runtime constraints to `^0.0.12`.

## 0.0.11

- Add `LxStreamCompletionPolicy.close` and `.retain`; `close` remains the
  compatibility default, while `retain` permits explicit source rebinding.
- Add `LxAsyncConcurrency.latest` and `.exhaustLatest` to async computed values
  and workers. `exhaustLatest` runs at most one trailing recomputation.
- Add `LxFamily<K, R>` for lazy keyed reactive resources, explicit
  invalidation, safe diagnostic key formatting, and optional inactivity
  eviction.

## 0.0.10
- Coordinated release version bump.

## 0.0.9
- Coordinated release version bump.

## 0.0.8
- Preserved original stack traces when synchronous `LxComputed` evaluations fail.
- Deprecated the legacy `LevitReactiveBatch.fromChanges` factory.
- Coordinated release version bump.

## 0.0.7
- Bumped version to 0.0.7

## 0.0.6

### Breaking Changes
- **Renamed** `LevitStateMiddlewareChain` to `LevitReactiveMiddlewareChain`.
- Added `isSensitive` property to `LxReactive` interface.

### New Features
- Added `isSensitive` parameter to `lxVar` and `LxReactive` to mark sensitive data (e.g., passwords/tokens) for obfuscation in DevTools/Monitor.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Performance and stability improvements

## 0.0.4

- Unified `LevitReactiveMiddleware` architecture.
- Optimized `LxComputed` with batching and smarter dependency tracking.
- Added `LxLxStatus` and improved asynchronous types.
- Fixed memory leaks in deep reactive graphs.
- Performance improvements for large-scale state mutations.

## 0.0.3

- Linting fixes and strict analysis compliance.
- Refactored test coverage for `LxAsyncComputed`.

## 0.0.2

- Added documentation for `LxError`, `LxAsyncComputed`, `LevitReactiveHistoryMiddleware`, `LevitReactiveMiddleware`, and `LevitReactiveNotifier`.
- Fixed lint issues in `core.dart`.
- Added example project.

## 0.0.1

- Initial release.
