# levit_monitor

[![Pub Version](https://img.shields.io/pub/v/levit_monitor)](https://pub.dev/packages/levit_monitor)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_monitor)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**Unified observability and diagnostics for the Levit ecosystem.**

`levit_monitor` provides deep visibility into the runtime behavior of your application by capturing and correlating events from both the dependency injection system (`levit_scope`) and the reactive state engine (`levit_reactive`).

---

## Purpose & Scope

`levit_monitor` aggregates diagnostic data into a single, serializable pipeline. It is responsible for:
- Collecting lifecycle and resolution events from the DI container.
- Capturing state mutations and dependency graph changes from the reactive engine.
- Providing pluggable transports for local logging or remote visualization.
- Enabling monotonic correlation of events across asynchronous transitions.

---

## Conceptual Overview

### Core Abstractions
- **[LevitMonitor]**: The global hub for attaching and configuring the monitoring system.
- **[MonitorEvent]**: The sealed base class for all serializable diagnostic records.
- **[LevitTransport]**: An interface for event destinations (Console, File, WebSocket).
- **[LevitMonitorMiddleware]**: The bridge that intercepts internal framework calls and generates monitoring events.

---

## Getting Started

### Basic Attachment
```dart
import 'package:levit_monitor/levit_monitor.dart';

void main() {
  // Starts capturing events and piping them to the console
  LevitMonitor.attach();
  
  // Your application logic here
}
```

### Event Filtering
```dart
// Only monitor Dependency Injection events
LevitMonitor.setFilter((event) => event is DependencyEvent);
```

---

## Design Principles

### Transparent Instrumentation
Monitoring is attached non-intrusively via middlewares. The application logic remains unaware of the diagnostics layer, ensuring zero footprint when detached.

### Monotonicity
Every event is tagged with a monotonic sequence number and a session ID. This allows tools to reconstruct the exact order of operations, even when events are processed out-of-order by external consumers.

### Serializable Schema
All events implement a `toJson()` method and follow a strictly typed hierarchy. This makes it trivial to stream diagnostics to external DevTools, databases, or analytics services.
