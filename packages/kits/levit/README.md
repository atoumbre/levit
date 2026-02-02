# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit)](https://codecov.io/github/atoumbre/levit)

**The pure Dart logic kernel of the Levit ecosystem.**

This package bundles everything you need to build reactive, robust business logic in Dart. It includes:
*   [levit_reactive]: Signals (`.lx`), Effects, and Computed values.
*   [levit_scope]: A powerful hierarchical dependency injection system.
*   [levit_dart]: Utilities for structured concurrency and tasks.

It is **framework-agnostic**. Use it for CLI tools, servers, or the domain layer of your Flutter apps.

---

## Quick Start

```dart
import 'package:levit/levit.dart';

void main() {
  // 1. Reactivity
  final count = 0.lx;
  
  Lx.effect(() {
    print("Count is: ${count.value}");
  });
  
  // 2. Dependency Injection
  final scope = Levit.createScope('main');
  
  scope.put(() => AuthService());
  
  final auth = scope.find<AuthService>();
}
```

## Installation

```yaml
dependencies:
  levit: ^latest
```

> **Building a Flutter app?**
> You probably want `levit_flutter` instead, which includes this package plus widget bindings.
