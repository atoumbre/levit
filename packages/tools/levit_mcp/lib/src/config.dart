/// @docImport 'server.dart';
/// @docImport 'websocket_relay.dart';
library;

import 'dart:math';

import 'package:args/args.dart';

/// Generates a 128-bit cryptographically random hexadecimal authentication
/// token (32 lowercase hex characters).
///
/// Uses `Random.secure()` by default; pass [random] to inject a deterministic
/// generator in tests.
///
/// {@category Server & Configuration}
String generateAuthToken([Random? random]) {
  final rng = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Configuration for [LevitMcpServer] and [LevitWebSocketRelay].
///
/// {@category Server & Configuration}
final class LevitMcpConfig {
  /// Default loopback port for the WebSocket telemetry relay.
  static const int defaultPort = 9200;

  /// Loopback port to bind (`0` selects an ephemeral OS port).
  final int port;

  /// Authentication token required on incoming `/ws` producer connections.
  final String token;

  /// Whether [token] was auto-generated rather than supplied explicitly.
  final bool tokenGenerated;

  /// Explicit browser `Origin` allowlist for Flutter Web debug sessions.
  ///
  /// Empty by default, which rejects all browser `Origin` headers to prevent
  /// Cross-Site WebSocket Hijacking (CSWSH).
  final Set<String> allowWebOrigins;

  /// Maximum number of tracked sessions retained simultaneously.
  final int maxSessions;

  /// Maximum concurrent active WebSocket producer connections.
  final int maxConnections;

  /// Maximum UTF-8 byte length accepted for a single incoming event frame.
  final int maxMessageBytes;

  /// Maximum number of recent events retained per session snapshot.
  final int historyCapacity;

  /// Maximum number of reactive variables retained per session snapshot.
  final int maxVariables;

  /// Maximum recursion depth returned by `inspect_task_tree`.
  final int maxTaskTreeDepth;

  /// Creates a validated MCP server configuration.
  ///
  /// Defaults:
  /// - [port]: [defaultPort] (`9200`; use `0` for an ephemeral loopback port).
  /// - [token]: Auto-generated via [generateAuthToken] when omitted or empty,
  ///   setting [tokenGenerated] to `true`.
  /// - [allowWebOrigins]: Empty (rejects all browser `Origin` headers).
  /// - [maxSessions]: `16` (must be `>= 1`).
  /// - [maxConnections]: `32` (must be `>= 1`).
  /// - [maxMessageBytes]: `262144` (256 KiB; must be `>= 1024`).
  /// - [historyCapacity]: `500` (must be `>= 0`).
  /// - [maxVariables]: `4096` (must be `>= 1`).
  /// - [maxTaskTreeDepth]: `16` (must be `>= 1`).
  ///
  /// Pass [random] to control token generation in tests. Throws [RangeError] if
  /// any numeric bound is violated (including [port] outside `0..65535`).
  ///
  /// ```dart
  /// final config = LevitMcpConfig(
  ///   port: 9200,
  ///   token: 'dev-local-token',
  ///   allowWebOrigins: {'http://localhost:8080'},
  /// );
  /// ```
  LevitMcpConfig({
    this.port = defaultPort,
    String? token,
    Set<String> allowWebOrigins = const {},
    this.maxSessions = 16,
    this.maxConnections = 32,
    this.maxMessageBytes = 256 * 1024,
    this.historyCapacity = 500,
    this.maxVariables = 4096,
    this.maxTaskTreeDepth = 16,
    Random? random,
  }) : token =
           (token == null || token.isEmpty) ? generateAuthToken(random) : token,
       tokenGenerated = token == null || token.isEmpty,
       allowWebOrigins = Set.unmodifiable(allowWebOrigins) {
    if (port < 0 || port > 65535) {
      throw RangeError.range(port, 0, 65535, 'port');
    }
    if (maxSessions < 1) {
      throw RangeError.value(maxSessions, 'maxSessions');
    }
    if (maxConnections < 1) {
      throw RangeError.value(maxConnections, 'maxConnections');
    }
    if (maxMessageBytes < 1024) {
      throw RangeError.value(maxMessageBytes, 'maxMessageBytes');
    }
    if (historyCapacity < 0) {
      throw RangeError.value(historyCapacity, 'historyCapacity');
    }
    if (maxVariables < 1) {
      throw RangeError.value(maxVariables, 'maxVariables');
    }
    if (maxTaskTreeDepth < 1) {
      throw RangeError.value(maxTaskTreeDepth, 'maxTaskTreeDepth');
    }
  }

  /// Builds the CLI argument parser for `levit_mcp`.
  static ArgParser buildArgParser() =>
      ArgParser()
        ..addOption(
          'port',
          abbr: 'p',
          defaultsTo: '$defaultPort',
          help:
              'Loopback port for LevitWebSocketTransport connections (0 for auto).',
        )
        ..addOption(
          'token',
          abbr: 't',
          help:
              'Shared secret token required by producers '
              '(defaults to LEVIT_MCP_TOKEN or a generated token).',
        )
        ..addMultiOption(
          'allow-web-origin',
          help:
              'Allow a specific browser Origin header for Flutter Web debug apps '
              '(e.g. http://localhost:8080). May be repeated.',
        )
        ..addOption(
          'history-capacity',
          defaultsTo: '500',
          help: 'Maximum number of recent events retained per session.',
        )
        ..addOption(
          'max-sessions',
          defaultsTo: '16',
          help: 'Maximum number of sessions tracked simultaneously.',
        )
        ..addOption(
          'max-connections',
          defaultsTo: '32',
          help: 'Maximum concurrent WebSocket producer connections.',
        )
        ..addFlag(
          'help',
          abbr: 'h',
          negatable: false,
          help: 'Print usage information and exit.',
        );

  /// Usage text for CLI `--help` output.
  static String get usage => buildArgParser().usage;

  /// Parses CLI [args] and optional [environment] into a [LevitMcpConfig].
  ///
  /// Supported flags: `--port` (`-p`), `--token` (`-t`), `--allow-web-origin`
  /// (repeatable), `--history-capacity`, `--max-sessions`, `--max-connections`,
  /// and `--help` (`-h`).
  ///
  /// Token precedence is `--token` > `environment['LEVIT_MCP_TOKEN']` >
  /// auto-generated 128-bit hex token via [generateAuthToken] using [random].
  ///
  /// Returns `null` when `--help` is passed. Throws [FormatException] (or
  /// `ArgParserException`) for invalid numeric values or unknown options.
  static LevitMcpConfig? parseArgs(
    List<String> args, {
    Map<String, String> environment = const {},
    Random? random,
  }) {
    final results = buildArgParser().parse(args);
    if (results.flag('help')) return null;

    int parsePositiveInt(String name, {int min = 1, int? max}) {
      final raw = results.option(name)!;
      final value = int.tryParse(raw);
      if (value == null || value < min || (max != null && value > max)) {
        throw FormatException('Invalid value for --$name: $raw');
      }
      return value;
    }

    final cliToken = results.option('token');
    final envToken = environment['LEVIT_MCP_TOKEN'];
    final effectiveToken =
        (cliToken != null && cliToken.isNotEmpty) ? cliToken : envToken;

    return LevitMcpConfig(
      port: parsePositiveInt('port', min: 0, max: 65535),
      token: effectiveToken,
      allowWebOrigins: results.multiOption('allow-web-origin').toSet(),
      historyCapacity: parsePositiveInt('history-capacity', min: 0),
      maxSessions: parsePositiveInt('max-sessions', min: 1),
      maxConnections: parsePositiveInt('max-connections', min: 1),
      random: random,
    );
  }
}
