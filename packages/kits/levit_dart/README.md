# levit_dart

[![Pub Version](https://img.shields.io/pub/v/levit_dart)](https://pub.dev/packages/levit_dart)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_dart)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_dart)](https://codecov.io/github/atoumbre/levit)

**Supercharged utilities for Levit Controllers.**

`levit_dart` extends the core framework with advanced mixins and patterns for real-world application development.

It includes:
*   **Loop Engine**: A robust system for running tasks periodically or continuously.
*   **Task Engine**: Structured concurrency with busy states and error handling.
*   **Pagination**: Helpers for managing list data.

---

## Installation

```yaml
dependencies:
  levit_dart: ^latest
```

(Note: If you use `levit` or `levit_flutter`, this is already included.)

## Example: Loop execution

```dart
class Worker extends LevitController with LevitLoopExecutionMixin {
  @override
  void onInit() {
    super.onInit();
    
    // Start a periodic task
    loopEngine.start(
      'sync_data',
      (controller) async => await sync(),
      period: Duration(minutes: 5),
    );
  }
}
```
