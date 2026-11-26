/// Read-only Model Context Protocol (MCP) server for live Levit runtime
/// inspection.
///
/// `levit_mcp` accepts authenticated loopback WebSocket telemetry from Dart and
/// Flutter applications instrumented with `levit_monitor`
/// (`LevitWebSocketTransport`) and exposes structured inspection tools and
/// session resources to MCP clients over a `StreamChannel` (stdio via the
/// `levit_mcp` executable).
///
/// ## Key Components
///
/// - **Server & Configuration:** [LevitMcpServer], [LevitMcpConfig],
///   [generateAuthToken].
/// - **Loopback Relay & Security:** [LevitWebSocketRelay],
///   [LevitRelaySecurity], [constantTimeEquals].
/// - **Session Store & Diagnostics:** [LevitSessionStore], [LevitMcpSession],
///   [LevitRuntimeDiagnostics], [LevitDiagnosticFinding],
///   [LevitDiagnosticSeverity].
/// - **MCP Protocol Layer:** [LevitMcpProtocolServer] (exposes 6 read-only
///   tools and 2 `levit://` resources).
///
/// ## Programmatic Example
///
/// ```dart
/// import 'dart:io';
///
/// import 'package:dart_mcp/stdio.dart';
/// import 'package:levit_mcp/levit_mcp.dart';
///
/// Future<void> main() async {
///   final config = LevitMcpConfig(port: 9200, token: 'dev-local-token');
///   final server = await LevitMcpServer.start(
///     config: config,
///     channel: stdioChannel(input: stdin, output: stdout),
///     logSink: stderr,
///   );
///   await server.done;
///   await server.close();
/// }
/// ```
///
/// @docImport 'src/config.dart';
/// @docImport 'src/diagnostics.dart';
/// @docImport 'src/mcp_tools.dart';
/// @docImport 'src/security.dart';
/// @docImport 'src/server.dart';
/// @docImport 'src/session_store.dart';
/// @docImport 'src/websocket_relay.dart';
library;

export 'src/config.dart' show LevitMcpConfig, generateAuthToken;
export 'src/diagnostics.dart'
    show
        LevitDiagnosticFinding,
        LevitDiagnosticSeverity,
        LevitRuntimeDiagnostics;
export 'src/mcp_tools.dart' show LevitMcpProtocolServer;
export 'src/security.dart' show LevitRelaySecurity, constantTimeEquals;
export 'src/server.dart' show LevitMcpServer;
export 'src/session_store.dart' show LevitMcpSession, LevitSessionStore;
export 'src/websocket_relay.dart' show LevitWebSocketRelay;
