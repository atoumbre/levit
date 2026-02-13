# levit_reactive

[![Pub Version](https://img.shields.io/pub/v/levit_reactive)](https://pub.dev/packages/levit_reactive)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_reactive)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_reactive)](https://codecov.io/github/atoumbre/levit)

## Purpose & Scope

`levit_reactive` is the pure Dart reactive engine in the Levit ecosystem.

It is responsible for:
- Creating reactive state and derived state.
- Tracking dependencies between reactive producers and observers.
- Propagating updates deterministically, with optional batching.

It intentionally does not provide:
- Dependency injection or lifecycles (see `levit_scope` and `levit_dart_core`).
- Flutter widget bindings (see `levit_flutter_core` / `levit_flutter`).

## Conceptual Overview

`levit_reactive` models state as reactive objects that can be read, listened to, and closed.
Higher layers (controllers, stores, widgets) build on top of these primitives to manage ownership and disposal.

Common building blocks include:
- Reactive variables created with the `.lx` extension.
- Derived values computed with `LxComputed`.
- Side-effect observers driven by `LxWorker`.
- Transaction-like grouping of updates using `Lx.batch` / `Lx.batchAsync`.

## Getting Started

Install:

```yaml
dependencies:
  levit_reactive: ^latest
```

Minimal usage:

```dart
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  final count = 0.lx;
  final doubled = LxComputed(() => count() * 2);

  final log = LxWorker(doubled, (v) => print('doubled: $v'));

  count(1);
  count(2);

  log.close();
  doubled.close();
  count.close();
}
```

## Middleware Lifecycle (Token-Based)

Use one token per concern so registration is idempotent and updates are replace-in-place.

```dart
import 'package:levit_reactive/levit_reactive.dart';

const historyToken = #state_history;
const analyticsToken = #state_analytics;

class StateAnalyticsMiddleware extends LevitReactiveMiddleware {
  final bool v2;
  const StateAnalyticsMiddleware({this.v2 = false});
}

void configureStateMiddlewares() {
  Lx.addMiddleware(LevitReactiveHistoryMiddleware(), token: historyToken);
  Lx.addMiddleware(StateAnalyticsMiddleware(), token: analyticsToken);
}

void upgradeAnalyticsMiddleware() {
  Lx.addMiddleware(StateAnalyticsMiddleware(v2: true), token: analyticsToken);
}

void teardownStateAnalytics() {
  Lx.removeMiddlewareByToken(analyticsToken);
}
```

Canonical pattern:
- App-level state middleware: one stable token per global concern.
- Feature-level middleware: one token per feature concern.
- Teardown: remove by token when the concern is no longer active.

## Design Principles

- Determinism: propagation is synchronous and ordered.
- Fine-grained updates: observers react only to the reactive values they read.
- Explicit ownership: reactive objects are closed explicitly, or by higher-level lifecycle managers.
- No code generation or reflection.
