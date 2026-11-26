import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import 'config.dart';
import 'mcp_tools.dart';
import 'session_store.dart';
import 'websocket_relay.dart';

/// Top-level coordinator combining [LevitWebSocketRelay], [LevitSessionStore],
/// and [LevitMcpProtocolServer].
///
/// Use [start] to bind the loopback telemetry relay and attach an MCP protocol
/// channel in one call, and [close] to tear down both cleanly.
///
/// {@category Server & Configuration}
final class LevitMcpServer {
  /// Active server configuration.
  final LevitMcpConfig config;

  /// Session store shared between the WebSocket relay and MCP tools.
  final LevitSessionStore store;

  /// Authenticated loopback WebSocket relay for monitored Levit apps.
  final LevitWebSocketRelay relay;

  /// Underlying MCP protocol server handling client requests over the
  /// configured `StreamChannel`.
  final LevitMcpProtocolServer protocolServer;

  bool _closed = false;

  LevitMcpServer._({
    required this.config,
    required this.store,
    required this.relay,
    required this.protocolServer,
  });

  /// Starts the loopback WebSocket relay and attaches the MCP protocol server
  /// to [channel].
  ///
  /// - [config]: Relay port, authentication token, origin allowlist, and
  ///   retention limits.
  /// - [channel]: Bidirectional JSON-RPC channel to the MCP client (such as
  ///   `stdioChannel`).
  /// - [logSink]: Optional sink (typically `stderr`) for startup diagnostics so
  ///   `stdout` remains clean for MCP JSON-RPC. Always writes the bound
  ///   `ws://127.0.0.1:<port>/ws` URI, and writes the authentication token only
  ///   when `config.tokenGenerated` is `true`.
  /// - [clock]: Optional clock injected into [LevitSessionStore] for
  ///   deterministic session timestamps in tests.
  ///
  /// ```dart
  /// final server = await LevitMcpServer.start(
  ///   config: LevitMcpConfig(port: 0, token: 'secret'),
  ///   channel: clientChannel,
  /// );
  /// print('Connect producers to ${server.wsUri}');
  /// await server.done;
  /// await server.close();
  /// ```
  static Future<LevitMcpServer> start({
    required LevitMcpConfig config,
    required StreamChannel<String> channel,
    StringSink? logSink,
    DateTime Function()? clock,
  }) async {
    final store = LevitSessionStore(
      maxSessions: config.maxSessions,
      historyCapacity: config.historyCapacity,
      maxVariables: config.maxVariables,
      clock: clock,
    );
    final relay = await LevitWebSocketRelay.bind(config: config, store: store);
    final protocolServer = LevitMcpProtocolServer(
      channel,
      store: store,
      maxTaskTreeDepth: config.maxTaskTreeDepth,
    );

    logSink?.writeln('levit_mcp listening on ${relay.wsUri}');
    if (config.tokenGenerated) {
      logSink?.writeln('levit_mcp generated auth token: ${config.token}');
    }

    return LevitMcpServer._(
      config: config,
      store: store,
      relay: relay,
      protocolServer: protocolServer,
    );
  }

  /// Bound loopback WebSocket port.
  int get port => relay.port;

  /// Loopback WebSocket URI for producer apps.
  Uri get wsUri => relay.wsUri;

  /// Authentication token required on incoming producer connections.
  String get token => config.token;

  /// Completes when the MCP client channel closes.
  Future<void> get done => protocolServer.done;

  /// Gracefully shuts down both the MCP protocol server and WebSocket relay.
  ///
  /// Idempotent: subsequent calls after the first return immediately. Shuts
  /// down [protocolServer] before closing [relay].
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await protocolServer.shutdown();
    await relay.close();
  }
}
