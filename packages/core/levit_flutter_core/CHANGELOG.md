
## 0.0.9
- Unnamed `LScope` / `LAsyncScope` / `LScopedView` / route-scope fallbacks now get unique diagnostic names, so nested unnamed scopes no longer spam duplicate-name warnings.
- Clarified `LView` / `LScopedView` `autoWatch` docs: read reactives directly in `buildView`; do not wrap the entire tree in `LWatch`.
- Expanded overlay capture docs; prefer kit `showLevit*` helpers for imperative dialogs/sheets.
- Coordinated release version bump.

## 0.0.8
- Hardened `LScope` and `LAsyncScope` parent-scope rebinding when widgets move between parents.
- Tightened scope configuration callback typing and split scope/provider internals into smaller library parts without changing the public API.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.8`.

## 0.0.7

### Breaking Changes
- Removed `LAsyncScopedView`; use explicit `LAsyncScope + LView` composition instead.

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
