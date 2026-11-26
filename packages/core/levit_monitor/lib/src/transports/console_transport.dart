part of '../monitor_library.dart';

/// Log levels for Levit Monitor events.
///
/// {@category Middleware & Monitoring}
enum LevitLogLevel {
  /// No output.
  off(10000, 'OFF', '', ''),

  /// Fatal errors.
  fatal(6000, 'FATAL', '👾', '\x1B[35m'),

  /// Error level.
  error(5000, 'ERROR', '⛔', '\x1B[31m'),

  /// Warning level.
  warning(4000, 'WARN', '⚠️', '\x1B[33m'),

  /// Info level (default for DI register, DI delete, and scope progress events).
  info(3000, 'INFO', '💡', '\x1B[34m'),

  /// Debug level (default for batch, reactive init/dispose/graph/metadata,
  /// listener add/remove, DI resolve/create/init, scope create/dispose, and
  /// snapshot events).
  debug(2000, 'DEBUG', '🐛', '\x1B[36m'),

  /// Trace level (default for state changes).
  trace(1000, 'TRACE', '🔍', '\x1B[90m'),

  /// All output (for threshold configuration only; do not assign as an event
  /// log level).
  all(0, 'ALL', '', '');

  /// Numeric severity matching standard log ordering (`all < trace < ... < off`).
  final int value;

  final String _badge;
  final String _emoji;
  final String _ansi;

  const LevitLogLevel(this.value, this._badge, this._emoji, this._ansi);
}

/// Formats a single console log line for [LevitConsoleTransport].
typedef LevitLogFormatter =
    String Function(LevitLogLevel level, String message);

/// Writes a formatted console log line produced by [LevitConsoleTransport].
typedef LevitLogOutput = void Function(String line);

/// Configuration for log level overrides per event type.
///
/// Allows fine-grained control over the [LevitLogLevel] assigned to each
/// monitor event type. Only loggable levels (`trace` through `fatal`) may be
/// assigned — using [LevitLogLevel.off] or [LevitLogLevel.all] as an event
/// level throws an [ArgumentError]. To suppress specific event types
/// completely, use [LevitMonitor.setFilter].
///
/// ```dart
/// LevitConsoleTransport(
///   minLevel: LevitLogLevel.debug,
///   levelOverrides: const LevitLogLevelConfig(
///     stateChange: LevitLogLevel.debug, // Promote state changes to debug
///     diResolve: LevitLogLevel.trace,   // Demote DI resolve below minLevel
///   ),
/// )
/// ```
///
/// {@category Middleware & Monitoring}
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

  /// Log level for listener added events.
  final LevitLogLevel? listenerAdd;

  /// Log level for listener removed events.
  final LevitLogLevel? listenerRemove;

  /// Creates per-event-type log level overrides for [LevitConsoleTransport].
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
    this.listenerAdd,
    this.listenerRemove,
    this.reactiveError,
  });

  /// Log level for reactive error events.
  final LevitLogLevel? reactiveError;
}

/// A transport that logs formatted events to the console.
///
/// Provides structured logging with configurable log levels for each event
/// type. When attached through [LevitMonitor], events are frozen into
/// [LevitEventEnvelope]s before delivery and logged as JSON strings; unfrozen
/// typed events passed directly to [send] are formatted with human-readable
/// summaries.
///
/// ## Default Log Levels
///
/// | Event Type | Default Level |
/// |------------|---------------|
/// | State Change | `trace` |
/// | Batch | `debug` |
/// | Reactive Init / Dispose / Graph / Metadata | `debug` |
/// | Listener Add / Remove | `debug` |
/// | Reactive Error | `error` |
/// | DI Register / Delete | `info` |
/// | DI Resolve / Create / Init | `debug` |
/// | Scope Create / Dispose | `debug` |
/// | Scope Progress | `info` |
/// | Snapshot | `debug` |
/// | Log / Custom | Event's own `level` |
///
/// ## Usage
///
/// ```dart
/// // Basic usage with defaults
/// await LevitMonitor.attach(transport: LevitConsoleTransport());
///
/// // Customize minimum log level (hide trace/debug)
/// await LevitMonitor.attach(
///   transport: LevitConsoleTransport(minLevel: LevitLogLevel.info),
/// );
///
/// // Promote or demote specific event levels relative to minLevel
/// await LevitMonitor.attach(
///   transport: LevitConsoleTransport(
///     minLevel: LevitLogLevel.debug,
///     levelOverrides: const LevitLogLevelConfig(
///       stateChange: LevitLogLevel.debug,
///       diResolve: LevitLogLevel.trace,
///     ),
///   ),
/// );
/// ```
///
/// {@category Middleware & Monitoring}
class LevitConsoleTransport extends LevitTransport {
  /// The minimum log level to output.
  ///
  /// Events below this level are suppressed.
  final LevitLogLevel minLevel;

  /// Optional overrides for log levels per event type.
  final LevitLogLevelConfig? levelOverrides;

  /// Whether ANSI color escape codes are included in default output.
  final bool colors;

  /// Whether level emojis are included in default output.
  final bool includeEmojis;

  final LevitLogFormatter? _formatter;
  final LevitLogOutput _output;
  bool _closed = false;

  /// Creates a new [LevitConsoleTransport].
  ///
  /// * [minLevel]: Minimum log level to output. Defaults to [LevitLogLevel.trace].
  /// * [levelOverrides]: Optional per-event-type log level overrides.
  /// * [colors]: Whether to include ANSI colors in default formatting.
  /// * [includeEmojis]: Whether to include level emojis in default formatting.
  /// * [formatter]: Optional custom formatter receiving the resolved
  ///   [LevitLogLevel] and formatted message body.
  /// * [output]: Optional sink callback receiving each rendered line. Defaults
  ///   to [print].
  LevitConsoleTransport({
    this.minLevel = LevitLogLevel.trace,
    this.levelOverrides,
    this.colors = true,
    this.includeEmojis = true,
    LevitLogFormatter? formatter,
    LevitLogOutput? output,
  }) : _formatter = formatter,
       _output = output ?? print;

  @override
  void send(LevitMonitorEvent event) {
    if (_closed) return;
    final level = _levelFor(event);
    if (level.value < minLevel.value) return;
    if (level == LevitLogLevel.off || level == LevitLogLevel.all) {
      throw ArgumentError.value(
        level,
        'level',
        'LevitLogLevel.${level.name} can only be used as a minLevel threshold.',
      );
    }

    final message = _formatMessage(event);
    final line = _formatter != null
        ? _formatter(level, message)
        : _defaultFormat(level, message);
    _output(line);
  }

  String _defaultFormat(LevitLogLevel level, String message) {
    final prefix = includeEmojis
        ? '${level._emoji} [${level._badge}]'
        : '[${level._badge}]';
    return colors
        ? '${level._ansi}$prefix $message\x1B[0m'
        : '$prefix $message';
  }

  LevitLogLevel _levelFor(LevitMonitorEvent event) {
    final overrides = levelOverrides;

    return switch (event) {
      _ScopeProgressEvent() => LevitLogLevel.info,
      LevitFrozenMonitorEvent e => _frozenLevel(e),
      LevitReactiveMetadataEvent _ => LevitLogLevel.debug,
      LevitReactiveChangeEvent _ =>
        overrides?.stateChange ?? LevitLogLevel.trace,
      LevitReactiveBatchEvent _ => overrides?.batch ?? LevitLogLevel.debug,
      LevitReactiveInitEvent _ =>
        overrides?.reactiveInit ?? LevitLogLevel.debug,
      LevitReactiveDisposeEvent _ =>
        overrides?.reactiveDispose ?? LevitLogLevel.debug,
      LevitReactiveGraphChangeEvent _ =>
        overrides?.graphChange ?? LevitLogLevel.debug,
      LevitDependencyRegisterEvent _ =>
        overrides?.diRegister ?? LevitLogLevel.info,
      LevitDependencyResolveEvent _ =>
        overrides?.diResolve ?? LevitLogLevel.debug,
      LevitDependencyDeleteEvent _ => overrides?.diDelete ?? LevitLogLevel.info,
      LevitDependencyInstanceCreateEvent _ =>
        overrides?.diCreate ?? LevitLogLevel.debug,
      LevitDependencyInstanceReadyEvent _ =>
        overrides?.diInit ?? LevitLogLevel.debug,
      LevitReactiveListenerAddedEvent _ =>
        overrides?.listenerAdd ?? LevitLogLevel.debug,
      LevitReactiveListenerRemovedEvent _ =>
        overrides?.listenerRemove ?? LevitLogLevel.debug,
      LevitReactiveErrorEvent _ =>
        overrides?.reactiveError ?? LevitLogLevel.error,
      LevitScopeCreateEvent _ => LevitLogLevel.debug,
      LevitScopeDisposeEvent _ => LevitLogLevel.debug,
      LevitSnapshotEvent _ =>
        LevitLogLevel.debug, // Default for LevitSnapshotEvent
      LevitCustomMonitorEvent e => e.level,
      LevitLogEvent e => e.level,
    };
  }

  LevitLogLevel _frozenLevel(LevitFrozenMonitorEvent event) {
    final data = event.toJson();
    final explicit = data['level'];
    if (explicit != null) {
      return LevitLogLevel.values.firstWhere(
        (level) => level.name == explicit,
        orElse: () => LevitLogLevel.info,
      );
    }
    return switch (data['type']) {
      'scope_progress' => LevitLogLevel.info,
      'state_change' => levelOverrides?.stateChange ?? LevitLogLevel.trace,
      'batch' => levelOverrides?.batch ?? LevitLogLevel.debug,
      'reactive_init' => levelOverrides?.reactiveInit ?? LevitLogLevel.debug,
      'reactive_dispose' =>
        levelOverrides?.reactiveDispose ?? LevitLogLevel.debug,
      'graph_change' => levelOverrides?.graphChange ?? LevitLogLevel.debug,
      'di_register' => levelOverrides?.diRegister ?? LevitLogLevel.info,
      'di_resolve' => levelOverrides?.diResolve ?? LevitLogLevel.debug,
      'di_delete' => levelOverrides?.diDelete ?? LevitLogLevel.info,
      'di_instance_create' => levelOverrides?.diCreate ?? LevitLogLevel.debug,
      'di_instance_init' => levelOverrides?.diInit ?? LevitLogLevel.debug,
      'listener_add' => levelOverrides?.listenerAdd ?? LevitLogLevel.debug,
      'listener_remove' =>
        levelOverrides?.listenerRemove ?? LevitLogLevel.debug,
      'reactive_error' => levelOverrides?.reactiveError ?? LevitLogLevel.error,
      _ => LevitLogLevel.debug,
    };
  }

  String _formatMessage(LevitMonitorEvent event) {
    String safeValue(dynamic value, {bool sensitive = false}) =>
        '${LevitMonitorEvent._stringify(value, isSensitive: sensitive)}';

    return switch (event) {
      _ScopeProgressEvent e => jsonEncode(e.toJson()),
      LevitFrozenMonitorEvent e => jsonEncode(e.toJson()),
      LevitReactiveMetadataEvent e => 'METADATA: ${e.reactive.name}',
      LevitReactiveChangeEvent e =>
        'VAL: ${e.reactive.name ?? '[anon]'} <${e.change.valueType}> -> ${safeValue(e.change.newValue, sensitive: e.reactive.isSensitive)}',
      LevitReactiveBatchEvent e =>
        'BATCH: ${e.change.batchId} (${e.change.length} changes)',
      LevitReactiveInitEvent e =>
        'INIT: ${e.reactive.name ?? '[anon]'} <${e.reactive.runtimeType}> = ${safeValue(e.reactive.value, sensitive: e.reactive.isSensitive)}',
      LevitReactiveDisposeEvent e => 'DISPOSE: ${e.reactive.name ?? '[anon]'}',
      LevitReactiveGraphChangeEvent e =>
        'GRAPH: ${e.reactive.name} dependencies changed',
      LevitDependencyRegisterEvent e =>
        'DI REGISTER: ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})',
      LevitDependencyResolveEvent e =>
        'DI RESOLVE: ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})',
      LevitDependencyDeleteEvent e =>
        'DI DELETE: ${e.key} from ${e.scopeName}#${e.scopeId} (${e.source})',
      LevitDependencyInstanceCreateEvent e => 'DI CREATE: ${e.key}',
      LevitDependencyInstanceReadyEvent e => 'DI INIT: ${e.key}',
      LevitReactiveListenerAddedEvent e =>
        'LISTENER ADD: ${e.reactive.name ?? '[anon]'} (Context: ${e.context})',
      LevitReactiveListenerRemovedEvent e =>
        'Listener removed: ${e.reactive.name} (Context: ${e.context?.type})',
      LevitReactiveErrorEvent e =>
        'ERROR: ${e.reactive?.name ?? '[anon]'} - ${safeValue(e.error, sensitive: e.reactive?.isSensitive ?? false)}',
      LevitScopeCreateEvent e =>
        'SCOPE CREATE: ${e.scopeName}#${e.scopeId} (Parent: ${e.parentScopeId})',
      LevitScopeDisposeEvent e => 'SCOPE DISPOSE: ${e.scopeName}#${e.scopeId}',
      LevitSnapshotEvent e => 'Snapshot sent (${e.state.length} items)',
      LevitCustomMonitorEvent e =>
        'CUSTOM ${e.namespace}:${e.name} ${safeValue(e.toJson()['attributes'])}'
            '${e.error != null ? '\nError: ${safeValue(e.error, sensitive: e.sensitive)}' : ''}',
      LevitLogEvent e =>
        'LOG: ${safeValue(e.data)}'
            '${e.error != null ? '\nError: ${safeValue(e.error)}' : ''}'
            '${e.stackTrace != null ? '\nStack: \n${e.stackTrace}' : ''}',
    };
  }

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  Future<void> close() async {
    _closed = true;
  }
}
