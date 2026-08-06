# Changelog

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
