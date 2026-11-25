# Scope Playground Example

## Purpose & Scope

`scope_playground` demonstrates scope hierarchy behavior and isolation guarantees in a Flutter UI.

## Conceptual Overview

The example focuses on:

- Nested scopes created with `LScope`.
- Local overrides per subtree.
- Deterministic cleanup when scoped widgets unmount.

## Getting Started

```bash
flutter pub get
flutter run
```

## Design Principles

- Scope boundaries should mirror UI ownership boundaries.
- Child scope overrides must remain isolated from parents.
- Disposal behavior should be explicit and observable.

## Session replacement during cleanup

Switch sessions repeatedly while cleanup is running. The old connection closes before the latest requested session opens; intermediate requests coalesce. Loading and retry are visible. Widget tests install typed store overrides before resolution and await the lifecycle controller on unmount.

```bash
flutter run -d chrome -t lib/session_replacement.dart
flutter test
```
