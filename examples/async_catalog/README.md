# Async Catalog Example

## Purpose & Scope

`async_catalog` demonstrates async-first state modeling with Levit reactive status types and Flutter builders.

## Conceptual Overview

The example covers:

- Async data flows represented with `LxStatus` variants.
- Loading, success, and error rendering through status-aware builders.
- Refresh behavior that preserves predictable transition semantics.

## Getting Started

```bash
flutter pub get
flutter run
```

## Design Principles

- Encode async lifecycle explicitly in state, not ad-hoc booleans.
- Keep rendering logic aligned with status variants.
- Preserve deterministic refresh and retry transitions.
