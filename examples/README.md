# Levit Examples

This directory contains runnable reference applications that demonstrate package boundaries and recommended integration patterns across the Levit ecosystem.

## Purpose & Scope

Examples are responsible for:

- Showing practical composition of `levit_scope`, `levit_reactive`, and Flutter bindings.
- Demonstrating production-oriented patterns at increasing complexity.
- Providing runnable validation targets for documentation and onboarding.

Examples are not API specifications. Inline DartDoc and package READMEs remain authoritative.

## Available Examples

- [`task_board`](./task_board): CRUD plus save/upload task groups, cancellation and awaited repository cleanup.
- [`async_catalog`](./async_catalog): searchable pagination, stable query refresh, retained data and optimistic rollback.
- [`route_scopes`](./route_scopes): route-owned scope lifetime, covered/current visibility, and async route initialization.
- [`scope_playground`](./scope_playground): session replacement during cleanup, coalescing and typed store overrides in widget tests.
- [`nexus_studio`](./nexus_studio): advanced end-to-end client/server/shared architecture reference.

## Running an Example

```bash
cd examples/task_board
flutter pub get
flutter run
```
