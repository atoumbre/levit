
# Nexus Studio

**Nexus Studio** is a production-grade collaborative whiteboard application built entirely on **[Levit](https://github.com/your-repo/levit)**.

It serves as the **canonical reference implementation** for the Levit ecosystem, demonstrating how to design **scalable, high-performance, isomorphic Dart applications** that run seamlessly across client and server.

This is not a toy example. Nexus Studio implements real-world requirements such as real-time collaboration, optimistic UI, infinite undo/redo, authoritative server validation, and shared business logic—all with minimal boilerplate.

---

## Purpose and Scope

Nexus Studio exists to answer a concrete question:

> *What does a serious, end-to-end Levit application look like in practice?*

It is designed for:

* Engineers evaluating Levit for complex state management
* Teams interested in isomorphic Dart architectures
* Contributors looking for established patterns and best practices
* Architects assessing real-time collaboration and synchronization models

---

## Key Capabilities

Nexus Studio demonstrates the following production-ready features:

* **Real-Time Collaboration**
  Multiple users can concurrently create, move, resize, and recolor nodes with deterministic synchronization.

* **Live Presence**
  Real-time cursors and selections provide immediate awareness of other participants.

* **Isomorphic Core Engine**
  The `NexusEngine` runs identically on the Flutter client (optimistic execution) and the Dart server (authoritative validation).

* **Infinite Undo / Redo**
  A robust, middleware-driven history system implemented without polluting domain logic.

* **Fine-Grained Reactivity**
  UI updates are scoped to the exact state changes, avoiding unnecessary rebuilds even at scale.

---

## Architecture Overview

Nexus Studio adopts a **Client–Server–Shared** architecture that treats Dart as a true full-stack language when paired with Levit.

```mermaid
graph TD
    Client[Flutter App]
    Server[Dart Server]
    Shared[Shared Core Package]

    Client -->|Imports| Shared
    Server -->|Imports| Shared

    subgraph Shared Core (Isomorphic)
        Engine[NexusEngine]
        State[Lx Reactive State]
        Models[NodeModel, Vec2]
    end

    Client -- WebSocket --> Server
    Server -- Broadcast --> Client
```

### Shared Core: The Brain

**Location:** `example/shared`
**Dependencies:** Pure Dart only (no Flutter)

This package contains the complete domain model and business logic:

* `NexusEngine`: Central controller managing board state and commands
* Reactive models implemented using `Lx`
* Deterministic logic shared across environments

**Why this matters:**
The same code validates mutations on the server, applies optimistic updates on the client, and can be reused for simulation, testing, or replay.

---

### Server: The Authority

**Location:** `example/server`

A minimal Dart server responsible for:

* Hosting the authoritative `NexusEngine`
* Broadcasting delta-based state patches over WebSockets
* Validating client-originated mutations

The server is fully testable in isolation using `FakeWebSocketChannel`.

**Test Coverage:** 81%+
Includes unit tests and mocked network interactions.

---

### Client App: The Interface

**Location:** `example/app`

A Flutter application that:

* Renders state using `LWatch`
* Captures user gestures and forwards commands to the shared engine
* Applies optimistic updates while awaiting server confirmation

**Test Coverage:** 88%+
Includes widget tests, controller tests, and interaction flows.

---

## Levit Concepts in Practice

Nexus Studio is intentionally structured to highlight Levit’s core design pillars.

### Fine-Grained Reactivity (`levit_reactive`)

State is decomposed into individually observable properties rather than monolithic objects.

```dart
class NodeModel {
  final LxVar<Vec2> position;
  final LxInt color;

  NodeModel(...)
      : position = pos.lx,
        color = col.lx;
}
```

Only the affected properties notify listeners, even under heavy mutation loads.

---

### Isomorphic Logic (`levit_dart`)

The `NexusEngine` executes unchanged across client and server.

```dart
class NexusEngine extends LevitController {
  void bulkMove(Set<String> ids, Vec2 delta) {
    Lx.batch(() {
      for (final node in nodes) {
        if (ids.contains(node.id)) {
          node.position.value += delta;
        }
      }
    });
  }
}
```

Batching ensures a single notification cycle even for thousands of updates.

---

### Middleware-Driven History (`levit_reactive`)

Undo and redo are implemented via middleware, not manual bookkeeping.

```dart
final history = LevitStateHistoryMiddleware();

Lx.addMiddleware(
  history,
  filter: (change) => change.name.startsWith('node:'),
);

history.undo();
```

Domain logic remains clean, deterministic, and testable.

---

### Scoped Dependency Injection (`levit_scope`)

Lifecycle management is explicit and predictable.

* Long-lived global controllers (e.g., `NexusEngine`)
* Short-lived scoped controllers created and disposed automatically

```dart
showDialog(
  builder: (_) => LScope(
    create: () => StatsController(),
    child: StatsDialog(),
  ),
);
```

---

## Getting Started

### Prerequisites

* Flutter SDK 3.0+
* Dart SDK 3.0+

### One-Command Launch

From the `example` directory:

```bash
./run.sh
```

This starts the Dart server on port 8080 and launches the Flutter app on macOS.

---

### Manual Setup

**Server**

```bash
cd server
dart pub get
dart bin/server.dart
```

**Client**

```bash
cd app
flutter pub get
flutter run -d macos
```

---

## Testing and Quality

Nexus Studio follows strict testing and coverage standards.

* Unit tests for shared logic and controllers
* Widget tests for UI bindings and interactions
* Mocked WebSocket tests for synchronization behavior

### Running Tests

```bash
# Shared
cd shared
dart test

# Server
cd server
dart test

# App
cd app
flutter test
```

---

## Coverage Reporting

Coverage reports are available for all layers.

**App**

```bash
flutter test --coverage
lcov --list coverage/lcov.info
```

**Server**

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
lcov --list coverage/lcov.info
```

**Shared**

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
lcov --list coverage/lcov.info
```

---

## Project Structure

```
example/
├── app/        # Flutter client
├── server/     # Dart server
└── shared/     # Isomorphic core (pure Dart)
```

---

## Final Notes

Nexus Studio is not just an example—it is a **reference architecture**.
If you understand Nexus Studio, you understand how to build serious applications with Levit.

Built by the Levit team to set the bar for clarity, performance, and architectural discipline.
