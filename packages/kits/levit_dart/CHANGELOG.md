# Changelog

## Unreleased
- Refactored task-engine support code into smaller internal modules without changing the public API.

## 0.0.8
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.8`.

## 0.0.7
- Bumped version to 0.0.7

## 0.0.6

### Breaking Changes
- **Renamed Mixins**:
    - `LevitExecutionLoopMixin` -> `LevitLoopExecutionMixin`
- **FEAT**: Added `startIsolateLoop` to `LevitLoopExecutionMixin` for running background tasks in separate isolates.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Task management mixins with priority queuing
- Retry logic with exponential backoff
- Isolate task execution support

## 0.0.4
- Initial release
