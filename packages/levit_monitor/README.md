# Levit Monitor

[![Pub Version](https://img.shields.io/pub/v/levit_monitor)](https://pub.dev/packages/levit_monitor)
[![Platforms](https://img.shields.io/badge/platforms-dart-blue)](https://pub.dev/packages/levit_monitor)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/SoftiLab/levit/graph/badge.svg?token=ooSOnU6nkwg\&flag=levit_monitor)](https://codecov.io/github/atoumbre/levit?flags=levit_monitor)


A unified observability and diagnostics engine for the Levit ecosystem.

`levit_monitor` provides deep visibility into the runtime behavior of your application by capturing and correlating events from both the dependency injection system (`levit_dart`) and the reactive state engine (`levit_reactive`).

## Key Features

- **Unified Diagnostics**: A single pipeline for monitoring service lifecycles, dependency resolutions, and state mutations.
- **Pluggable Transports**: Multiple built-in transports (Console, File, WebSocket) for local debugging or external DevTools integration.
- **Monotonic Correlation**: Events are tagged with sequence numbers and session IDs to enable precise debugging across asynchronous gaps.
- **Predicated Filtering**: Granular control over volume and type of captured diagnostic data.

## Getting Started

### Installation

Add `levit_monitor` to your `pubspec.yaml`:

```yaml
dependencies:
  levit_monitor: latest
```

### Basic Attachment

The simplest way to start monitoring is to attach the default monitor at the entry point of your application. By default, it uses the `ConsoleTransport` to log JSON events to standard output.

```dart
import 'package:levit_monitor/levit_monitor.dart';

void main() {
  LevitMonitor.attach(); // Starts capturing events immediately
  
  // Your app entry
  runApp(MyApp());
}
```

## Advanced Configuration

### Using WebSockets for DevTools

To connect your application to an external visualizer (like Levit DevTools), use the `WebSocketTransport`:

```dart
import 'package:levit_monitor/levit_monitor.dart';
import 'package:web_channel/io.dart'; 

void main() {
  final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
  final transport = WebSocketTransport(channel);

  LevitMonitor.attach(transport: transport);
  
  runApp(MyApp());
}
```

### Event Filtering

You can suppress noisy events or focus on specific diagnostic categories using a global filter:

```dart
// Only monitor state mutations, ignoring DI and graph changes
LevitMonitor.setFilter((event) => event is ReactiveChangeEvent);
```

## Built-in Transports

- **ConsoleTransport**: Prettified or raw JSON logging to the terminal.
- **FileTransport**: Persists diagnostic events to the local filesystem.
- **WebSocketTransport**: Streams events to remote servers or DevTools.

## Monitoring Schema

All events follow a unified schema:

| Property | Description |
| :--- | :--- |
| `seq` | Monotonic sequence number. |
| `timestamp` | UTC ISO-8601 timestamp of the event. |
| `sessionId` | Correlates events within a single execution run. |
| `type` | The specific event identifier (e.g., `state_change`, `di_resolve`). |
