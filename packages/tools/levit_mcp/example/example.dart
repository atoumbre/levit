import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:levit_mcp/levit_mcp.dart';

/// Starts a read-only `levit_mcp` stdio server accepting authenticated
/// loopback `LevitWebSocketTransport` connections on port 9200.
Future<void> main() async {
  final server = await LevitMcpServer.start(
    config: LevitMcpConfig(port: 9200, token: 'dev-local-token'),
    channel: stdioChannel(input: stdin, output: stdout),
    logSink: stderr,
  );

  try {
    await server.done;
  } finally {
    await server.close();
  }
}
