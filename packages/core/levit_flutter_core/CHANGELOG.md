
## 0.0.6

### Breaking Changes
- **RENAMED** `LWatchVar` and `LWatchStatus` widgets renamed to `LBuilder` and `LStatusBuilder`.

### New Features
- **FEAT**: Added `LScopedView`, `LAsyncScopedView`, and `LScopedAsyncView` for simplified scoped dependency management.
- **FEAT**: Added static `put`, `lazyPut`, and `lazyPutAsync` factory methods to `LScope` and `LScopedView`.
- **FEAT**: Added `LSelectorBuilder` for sub-graph dependency view binding.
- **FIX**: Improved `LView` mounting performance.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Performance and stability improvements

## 0.0.4

- Optimized `LWatch` with fast-path for multiple dependencies.
- Reduced `LView` mounting overhead, improving "View Churn" metrics.
- Fixed reactivity issues in `LStatusBuilder`.
- Improved `BuildContext.levit` performance.

## 0.0.3

- Linting fixes and strict analysis compliance.

## 0.0.2

- Added documentation for `LxError`, `LScopedView`, `LState`, `LStatefulView`, and `LStatusBuilder`.
- Added example application.

## 0.0.1

- Initial release.
