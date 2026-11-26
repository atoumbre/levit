## 0.1.0-beta.1

- **Breaking:** Requires Dart 3.7+ and Flutter 3.29+.
- **Breaking:** Removed `LKeepAlive`; hoist state into an ancestor `LScope` / `LevitStore` or use Flutter's `AutomaticKeepAliveClientMixin` directly when off-screen retention is needed.
- Re-export the `0.1.0-beta.1` Flutter bindings and Dart kit APIs, including `LevitFlutter.ensureInitialized()` with automatic `ChangeNotifier` disposal, serialized scope replacement (`LevitScopeLifecycleController`), `LxReadable<T>` builders, `LxStatus.when`/`maybeWhen`, controller/store `computed`/`asyncComputed`, complete `LxStatus` callbacks on `LStatusBuilder`, `LevitTaskGroup`, task conflict-policy shorthand helpers, and `LevitAsyncMap`.
- Export borrowing `LevitValueListenable` / `asValueListenable()` interoperability and add a scoped countdown interop example (`example/lib/countdown_interop.dart`).
- Expose `package:levit_flutter/levit_testing.dart` (`LevitTestScope`, automatically invoking `LevitFlutter.ensureInitialized()`) for isolated testing.
- Updated internal package constraints to `^0.1.0-beta.1`.

## 0.0.12

- Expose the 0.0.12 runtime contracts; migrate examples and add executable Flutter onboarding coverage.
- Updated internal runtime constraints to `^0.0.12`.

## 0.0.11

- Re-export the 0.0.11 lifecycle, reactive, and task APIs.
- Await controller-owned cleanup from Flutter lifecycle mixins.
- Updated internal package constraints to `^0.0.11`.

## 0.0.10
- `LevitAppLifecycleMixin` and `LevitLoopExecutionLifecycleMixin`: `onClose()` is safe when called without `onInit()`.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.10`.

## 0.0.9
- Added `showLevitDialog` and `showLevitModalBottomSheet` (capture page scope by default).
- Updated README / LLM guidance for `autoWatch`, overlays, and dual lifetime styles.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.9`.


## 0.0.8
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.8`.
- Strengthened `LevitAppLifecycleMixin` observer coverage.

## 0.0.7
- Bumped version to 0.0.7

## 0.0.6

### Breaking Changes
- **Renamed Mixins**:
  - `LevitExecutionLoopMixin` -> `LevitLoopExecutionMixin`
  - `LevitLifecycleLoopMixin` -> `LevitLoopExecutionLifecycleMixin`

### Fixes
- **FIX**: Resolved lifecycle observer issues in `LevitLoopLifecycleMixin`.
- **FEAT**: Added comprehensive example project structure.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Flutter utility widgets and mixins
- App lifecycle observer mixin

## 0.0.4
- Initial release
