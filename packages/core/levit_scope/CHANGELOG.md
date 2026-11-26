## 0.1.0-beta.1

- **Breaking:** Requires Dart 3.7+.
- **Breaking:** Child scopes created via `createScope` are owned by their parent by default (`ownedByParent: true`) and dispose before parent dependencies.
- **Breaking:** Factory registrations are no longer implicitly permanent; pass `permanent: true` when needed and await `releaseFactoryInstance(instance)` for early release.
- **Breaking:** `delete`, `reset`, and `releaseFactoryInstance` reject self-disposal with `StateError` instead of deadlocking.
- Add `scope.runInitialization` to admit external setup work, drain it on closure, and guard against self-disposal.
- Add `scope.applyOverrides([...])` for scoped override installation and ensure `findOrNull` / `findOrNullAsync` return `null` only for missing registrations while propagating builder/type errors.
- Add `scope.describe()` immutable inspection snapshots and `LevitScopeProgressObserver` middleware hook for pending initialization and cleanup progress.

## 0.0.12

- **Breaking:** remove preconstructed instance/future registration extensions; retain builder forms.
- Own factory-created disposable results in the registering scope; await pending creation and cleanup during removal.
- Reject replacement while factory results or registration cleanup remain live.
- Updated internal runtime constraints to `^0.0.12`.

## 0.0.11

- **Breaking:** `LevitScopeDisposable.onClose()` may return `FutureOr<void>`;
  `delete`, `reset`, and `dispose` now await cleanup.
- Dispose registrations in LIFO order, continue after individual failures, and
  report them together as `LevitDisposalException`.
- Own `LevitDisposable` registrations directly and make terminal disposal
  idempotent.
- Add local, non-owning `bindExisting<Alias, Concrete>()` aliases for singleton
  registrations.
- Reject replacement of an instantiated synchronous registration; callers must
  `await delete` before registering its replacement.

## 0.0.10
- Coordinated release version bump.

## 0.0.9
- Clarified `permanent` DartDoc: survives non-forced `reset` only; `dispose()` always force-clears.
- Coordinated release version bump.

## 0.0.8
- Hardened middleware token registration and removal edge cases.
- Routed duplicate-scope-name diagnostics through structured debug logging.
- Coordinated release version bump.

## 0.0.7
- Bumped version to 0.0.7

## 0.0.6

### New Features
- Added middleware hooks for `onDependencyCreate` and `onDependencyInit`.
- Documentation updates.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Performance and stability improvements

## 0.0.4

- Package renamed from `levit_di` to `levit_scope`.
- Significant performance boost for `LevitScope` lookups (3x faster in concurrent scenarios).
- Improved `find` and `put` efficiency.
- Better handling of concurrent registrations and race conditions.
- Refined lifecycle hooks for disposables.

## 0.0.3

- Linting fixes and improved code quality.

## 0.0.2

- Added documentation for `LevitScopeDisposable`.
- Added example project.

## 0.0.1

- Initial release.
