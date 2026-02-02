
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
