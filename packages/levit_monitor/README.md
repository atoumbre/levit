# Levit Monitor

A comprehensive monitoring and observability package for the Levit framework.

## Features

- **Unified Monitoring**: Captures both Reactive State changes (`Lx`) and Dependency Injection events (`Levit`).
- **DevTools Integration**: Built-in WebSocket transport for connecting to external visualizers (like Levit DevTools).
- **Zero-Config**: Works out of the box with standard defaults.

## Usage

### Connecting to DevTools

To connect your application to an external DevTools instance (e.g., running on `localhost:8080`), simply attach the monitor with a `WebSocketTransport` at the start of your app:

```dart
import 'package:levit_monitor/levit_monitor.dart';
import 'package:web_socket_channel/io.dart'; // or html for web

void main() {
  // 1. Create the transport
  final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
  final transport = WebSocketTransport(channel);

  // 2. Attach the monitor
  LevitMonitor.attach(transport: transport);

  // ... run your app ...
}
```

### Manual Logging

For simple debugging, you can use the default `ConsoleTransport` which logs events to the terminal:

```dart
LevitMonitor.attach(); // Uses ConsoleTransport by default
```
