# Changelog

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
