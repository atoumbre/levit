# Route Scopes Example

## Purpose & Scope

`route_scopes` demonstrates when route lifetime is the meaningful ownership boundary in Flutter.

## Conceptual Overview

The example focuses on:

- `LRouteScope` for route-owned synchronous controller setup.
- `LAsyncRouteScope` for route-owned async initialization with loading UI.
- Reactive `current` / `covered` visibility updates through `LRouteVisibility`.
- Deterministic disposal when a route is popped or replaced.

## Getting Started

```bash
flutter pub get
flutter run
```

## Design Principles

- Keep route-local controllers tied to route lifetime, not arbitrary widget rebuilds.
- Make route coverage visible through a shared journal instead of implicit behavior.
- Use async route scopes only when the route itself owns the initialization step.
