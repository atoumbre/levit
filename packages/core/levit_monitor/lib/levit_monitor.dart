/// Monitoring and diagnostics runtime for Levit applications.
///
/// Captures structured events from dependency injection and reactive state
/// systems through [LevitMonitor], redacting sensitive data via
/// [LevitObfuscator] into immutable [LevitEventEnvelope]s and forwarding them
/// through configurable [LevitTransport]s ([LevitConsoleTransport],
/// [LevitWebSocketTransport], [LevitMultiTransport]; see
/// `package:levit_monitor/levit_monitor_io.dart` for `LevitFileTransport`).
///
/// Monitoring does not enable auto-linking; call `Levit.enableAutoLinking()`
/// explicitly during application bootstrap. `levit_monitor` is intentionally
/// independent of `levit_dart` — bridge task events through
/// [LevitMonitor.emitCustomEvent] at the application boundary.
///
/// ```dart
/// Levit.enableAutoLinking();
/// await LevitMonitor.attach(
///   transport: LevitConsoleTransport(minLevel: LevitLogLevel.info),
/// );
/// ```
///
/// MCP and custom inspector models live in `package:levit_monitor/spi.dart`.
///
/// @docImport 'src/monitor_library.dart';
library;

export 'src/monitor_library.dart'
    show
        LevitConsoleTransport,
        LevitDependencyEvent,
        LevitEventEnvelope,
        LevitLogEvent,
        LevitLogFormatter,
        LevitLogLevel,
        LevitLogLevelConfig,
        LevitLogOutput,
        LevitMonitor,
        LevitMonitorEvent,
        LevitMonitorException,
        LevitMultiTransport,
        LevitObfuscator,
        LevitReactiveEvent,
        LevitTransport,
        LevitWebSocketConnection,
        LevitWebSocketTransport;
