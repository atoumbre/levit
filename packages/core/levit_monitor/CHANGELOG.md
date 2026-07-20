
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
