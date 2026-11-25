## 0.1.0-beta.1

- Await attachment/replacement, flush and detach; aggregate delivery/cleanup failures.
- Freeze redacted envelopes before bounded queues/history; default history and worker statistics off.
- Add reconnect snapshots, delivery acknowledgements and drop accounting.
- Keep browser imports free of IO; move FileTransport to levit_monitor_io.dart.
- Add scope progress, reactive metadata, optional write stacks and application task adapter.
- Integrate the optional standalone levit_devtools local inspector.

## 0.0.12

- **Breaking:** attaching monitoring no longer enables auto-linking implicitly.
- Verify monitoring preserves explicit bootstrap configuration.
- Updated internal runtime constraints to `^0.0.12`.

## 0.0.11

- Add dependency-neutral `CustomMonitorEvent` and
  `LevitMonitor.emitCustomEvent` for application-layer adapters.
- Add stable namespaces/names, severity levels, safe structured serialization,
  complete sensitive-payload redaction, and custom-event transport formatting.
- Keep `levit_monitor` independent of higher-level kits such as `levit_dart`;
  task events are bridged by applications that import both.
- Updated internal package constraints to `^0.0.11`.

## 0.0.10
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.10`.

## 0.0.9
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.9`.

## 0.0.8
- Routed multi-transport failure diagnostics through structured debug logging.
- Coordinated release version bump.
- Updated internal package constraints to `^0.0.8`.

## 0.0.7

### Fixes
- **FIX**: Safely surfaced websocket connection errors via `onReady` and `onError` callbacks in `WebSocketTransport`.

## 0.0.6

### Breaking Changes
- Renamed `DependencyType.state` to `DependencyType.store`.

### New Features
- Added `LevitMonitor.setObfuscator` and `obfuscate` API to handle sensitive data in snapshots and events.
- Updated snapshot and event models to support `isSensitive` property.

## 0.0.5
- Production-ready documentation (Effective Dart compliance)
- Added `topics` to pubspec for improved discoverability
- Performance and stability improvements

## 0.0.4

- Added WebSocket transport for real-time DevTools communication.
- New `LevitReactiveMiddleware` for tracking reactive changes.
- Isolate-based transports for non-blocking monitoring.
- Enhanced event serialization for the DevTools.

## 0.0.1

- Initial release with WebSocket transport for DevTools communication.
