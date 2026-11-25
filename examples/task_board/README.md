# Task Board Example

## Purpose & Scope

`task_board` demonstrates a practical feature-level Flutter flow using Levit with scoped controller ownership and reactive UI updates.

## Conceptual Overview

The example focuses on:

- Controller lifecycle ownership via scoped registration.
- Reactive list mutation with derived selection/filtering state.
- Rebuild control using both `LWatch` and selector-focused builders.

## Getting Started

```bash
flutter pub get
flutter run
```

## Design Principles

- Keep controller ownership local to feature scope.
- Prefer selector-based rebuilds on hot render paths.
- Maintain explicit mutation and derivation boundaries.

## Save and upload workflow

A controller-owned supervisor root contains a save workflow and a child upload group. A failed upload cancels its sibling; cancel/unmount drains every finally block before the repository closes. The buttons expose success, cancellation and failure. The tests use completion signals to hold cleanup open and assert ordering.

```bash
flutter run -d chrome -t lib/save_upload.dart
flutter test
```
