# Nexus Studio

**Nexus Studio** is a production-grade, collaborative whiteboard application built from the ground up using the **Levit** framework.

It serves as the **authoritative reference architecture** for the Levit ecosystem, demonstrating how to design **scalable, high-performance, isomorphic Dart applications** that maintain seamless state synchronization across client and server.

---

## Architectural Philosophy

Nexus Studio is built on the premise that **business logic should be environment-agnostic**. By utilizing `levit_reactive` and `levit_dart`, the application's "brain" is written once in a shared package and executed identically on the Flutter client and the Dart server.

-   **Optimistic UI**: The client applies state changes immediately using the shared engine.
-   **Authoritative Validation**: The server runs the same engine to validate incoming commands and broadcast the final state.
-   **Atomic Synchronization**: Commands and state patches ensure that all participants remain in a deterministic, eventually consistent state.

---

## Project Structure

The project is divided into three distinct layers to enforce architectural discipline:

-   [`shared/`](./shared): The isomorphic core. Contains all reactive models, domain logic, and business rules. Pure Dart.
-   [`server/`](./server): The authoritative backend. Manages active sessions, broadcasts updates, and enforces security.
-   [`app/`](./app): The Flutter frontend. Responsible for rendering the reactive state and capturing user intent.

---

## Key Patterns Demonstrated

### 1. Fine-Grained Reactivity
Models use `LxVar`, `LxList`, and `LxComputed` to ensure that UI components only rebuild when the specific piece of state they observe changes.
[`shared.dart`](./shared/lib/shared.dart)

### 2. Isomorphic Controllers
The `NexusEngine` extends `LevitController`, allowing it to manage complex state transitions and lifecycle events in both Flutter and CLI environments.
[`controllers.dart`](./app/lib/controllers.dart)

### 3. Middleware-Driven Audit
The application uses built-in and custom middlewares to implement cross-cutting concerns like undo/redo history and real-time monitoring.
[`server.dart`](./server/lib/server.dart)

---

## Running the Reference App

### Prerequisites
-   Flutter SDK 3.x
-   Dart SDK 3.x

### One-Step Launch (Mac/Linux)
From the `examples/nexus_studio` directory:
```bash
./run.sh
```

### Manual Execution
1.  **Start the Server**:
    ```bash
    cd server && dart bin/server.dart
    ```
2.  **Start the Client**:
    ```bash
    cd app && flutter run
    ```

---

## Verification and Testing
Nexus Studio maintains a high standard of quality, with extensive test suites for each layer.

```bash
# Run all tests
cd shared && dart test
cd server && dart test
cd app && flutter test
```

### Coverage Audit
> [!NOTE]
> Coverage is strictly monitored to ensure that all shared logic and edge cases are validated before server broadcast.

