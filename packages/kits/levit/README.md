# levit

[![Pub Version](https://img.shields.io/pub/v/levit)](https://pub.dev/packages/levit)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**The core kit for building application logic with the Levit ecosystem.**

`levit` bundles and re-exports the foundational packages for reactive state management, dependency injection, and utility mixins. It serves as the primary gateway for building non-UI business logic.

---

## Purpose & Scope

`levit` provides a unified entry point for the "logic" side of Levit. It is responsible for:
- Re-exporting foundational reactivity primitives from `levit_reactive`.
- Re-exporting hierarchical dependency injection from `levit_scope`.
- Providing domain-level abstractions from `levit_dart`.

---

## Conceptual Overview

### Core Abstractions
- **[Lx]**: Static entry point for reactivity and batching.
- **[Ls]**: Static entry point for ambient dependency resolution.
- **[LevitScope]**: Hierarchical container for dependency management.

---

## Getting Started

### Installation
Add `levit` to your `pubspec.yaml`:
```yaml
dependencies:
  levit: latest
```

### Usage
```dart
import 'package:levit/levit.dart';

final count = 0.lx;
final auth = Ls.find<AuthService>();
```

---

## Design Principles

### All-in-One Gateway
Designed to simplify imports by providing a single, authoritative package that exports everything needed to build a fully reactive domain layer.

### Framework Agnostic
While it pairs perfectly with `levit_flutter`, the `levit` kit itself has zero dependencies on Flutter and runs in any Dart environment.
