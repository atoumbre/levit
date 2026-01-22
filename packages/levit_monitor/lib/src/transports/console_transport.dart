import 'package:logger/logger.dart';

import '../core/event.dart';
import '../core/transport.dart';

/// Log levels for Levit Monitor events.
///
/// These map to the underlying [Level] from the `logger` package.
enum LevitLogLevel {
  /// No output.
  off(Level.off),

  /// Fatal errors.
  fatal(Level.fatal),

  /// Error level.
  error(Level.error),

  /// Warning level.
  warning(Level.warning),

  /// Info level (default for DI events).
  info(Level.info),

  /// Debug level (default for init, dispose, graph changes).
  debug(Level.debug),

  /// Trace level (default for state changes).
  trace(Level.trace),

  /// All output.
  all(Level.all);

  final Level level;
  const LevitLogLevel(this.level);
}

/// Configuration for log level overrides per event type.
///
/// This allows fine-grained control over which events are logged at which level.
///
/// ```dart
/// ConsoleTransport(
///   levelOverrides: LevitLogLevelConfig(
///     stateChange: LevitLogLevel.debug, // Promote state changes to debug
///     diResolve: LevitLogLevel.off,     // Suppress DI resolve logs
///   ),
/// )
/// ```
class LevitLogLevelConfig {
  /// Log level for state change events.
  final LevitLogLevel? stateChange;

  /// Log level for batch events.
  final LevitLogLevel? batch;

  /// Log level for reactive init events.
  final LevitLogLevel? reactiveInit;

  /// Log level for reactive dispose events.
  final LevitLogLevel? reactiveDispose;

  /// Log level for graph change events.
  final LevitLogLevel? graphChange;

  /// Log level for DI register events.
  final LevitLogLevel? diRegister;

  /// Log level for DI resolve events.
  final LevitLogLevel? diResolve;

  /// Log level for DI delete events.
  final LevitLogLevel? diDelete;

  /// Log level for DI instance create events.
  final LevitLogLevel? diCreate;

  /// Log level for DI instance init events.
  final LevitLogLevel? diInit;

  const LevitLogLevelConfig({
    this.stateChange,
    this.batch,
    this.reactiveInit,
    this.reactiveDispose,
    this.graphChange,
    this.diRegister,
    this.diResolve,
    this.diDelete,
    this.diCreate,
    this.diInit,
  });
}

/// A transport that logs events to the console using the `logger` package.
///
/// This transport provides structured logging with configurable log levels
/// for each event type. It uses the popular `logger` package for beautiful,
/// readable console output.
///
/// ## Default Log Levels
///
/// | Event Type | Default Level |
/// |------------|---------------|
/// | State Change | `trace` |
/// | Batch | `debug` |
/// | Reactive Init | `debug` |
/// | Reactive Dispose | `debug` |
/// | Graph Change | `debug` |
/// | DI Register | `info` |
/// | DI Resolve | `debug` |
/// | DI Delete | `info` |
/// | DI Create | `debug` |
/// | DI Init | `debug` |
///
/// ## Usage
///
/// ```dart
/// // Basic usage with defaults
/// LevitMonitor.attach(transport: ConsoleTransport());
///
/// // Customize minimum log level (hide trace/debug)
/// LevitMonitor.attach(
///   transport: ConsoleTransport(minLevel: LevitLogLevel.info),
/// );
///
/// // Override specific event levels
/// LevitMonitor.attach(
///   transport: ConsoleTransport(
///     levelOverrides: LevitLogLevelConfig(
///       stateChange: LevitLogLevel.debug,      // Promote state changes
///       diResolve: LevitLogLevel.off,          // Suppress resolve logs
///     ),
///   ),
/// );
/// ```
class ConsoleTransport implements LevitTransport {
  /// The minimum log level to output.
  ///
  /// Events below this level will be suppressed.
  final LevitLogLevel minLevel;

  /// Optional overrides for log levels per event type.
  final LevitLogLevelConfig? levelOverrides;

  /// The underlying logger instance.
  final Logger _logger;

  /// Creates a new [ConsoleTransport].
  ///
  /// * [minLevel]: Minimum log level to output. Defaults to [LevitLogLevel.trace].
  /// * [levelOverrides]: Optional per-event-type log level overrides.
  /// * [printer]: Optional custom [LogPrinter]. Defaults to [PrettyPrinter].
  ConsoleTransport({
    this.minLevel = LevitLogLevel.trace,
    this.levelOverrides,
    LogPrinter? printer,
  }) : _logger = Logger(
          filter: ProductionFilter(),
          level: minLevel.level,
          printer: printer ??
              PrettyPrinter(
                methodCount: 0,
                errorMethodCount: 0,
                lineLength: 80,
                colors: true,
                printEmojis: true,
                dateTimeFormat: DateTimeFormat.none,
              ),
        );

  @override
  void send(MonitorEvent event) {
    final level = _levelFor(event);
    final message = _formatMessage(event);

    _logger.log(level.level, message);
  }

  LevitLogLevel _levelFor(MonitorEvent event) {
    final overrides = levelOverrides;

    return switch (event) {
      ReactiveChangeEvent _ => overrides?.stateChange ?? LevitLogLevel.trace,
      ReactiveBatchEvent _ => overrides?.batch ?? LevitLogLevel.debug,
      ReactiveInitEvent _ => overrides?.reactiveInit ?? LevitLogLevel.debug,
      ReactiveDisposeEvent _ =>
        overrides?.reactiveDispose ?? LevitLogLevel.debug,
      ReactiveGraphChangeEvent _ =>
        overrides?.graphChange ?? LevitLogLevel.debug,
      DependencyRegisterEvent _ => overrides?.diRegister ?? LevitLogLevel.info,
      DependencyResolveEvent _ => overrides?.diResolve ?? LevitLogLevel.debug,
      DependencyDeleteEvent _ => overrides?.diDelete ?? LevitLogLevel.info,
      DependencyInstanceCreateEvent _ =>
        overrides?.diCreate ?? LevitLogLevel.debug,
      DependencyInstanceReadyEvent _ =>
        overrides?.diInit ?? LevitLogLevel.debug,
    };
  }

  String _formatMessage(MonitorEvent event) {
    return switch (event) {
      ReactiveChangeEvent e =>
        'VAL: ${e.reactive.name ?? '[anon]'} -> ${e.change.newValue}',
      ReactiveBatchEvent e =>
        'BATCH: ${e.change.batchId} (${e.change.length} changes)',
      ReactiveInitEvent e =>
        'INIT: ${e.reactive.name ?? '[anon]'} = ${e.reactive.value}',
      ReactiveDisposeEvent e => 'DISPOSE: ${e.reactive.name ?? '[anon]'}',
      ReactiveGraphChangeEvent e =>
        'GRAPH: ${e.reactive.name} dependencies changed',
      DependencyRegisterEvent e =>
        'DI REGISTER: ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})',
      DependencyResolveEvent e =>
        'DI RESOLVE: ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})',
      DependencyDeleteEvent e =>
        'DI DELETE: ${e.key} from ${e.scopeName}#${e.scopeId} (${e.source})',
      DependencyInstanceCreateEvent e => 'DI CREATE: ${e.key}',
      DependencyInstanceReadyEvent e => 'DI INIT: ${e.key}',
    };
  }

  @override
  void close() {
    _logger.close();
  }
}
