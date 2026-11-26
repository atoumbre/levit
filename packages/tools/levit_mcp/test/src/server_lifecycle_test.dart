import 'dart:convert';
import 'dart:math';

import 'package:dart_mcp/client.dart';
import 'package:levit_mcp/levit_mcp.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/spi.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMcpServer end-to-end integration', () {
    test(
      'connects a real LevitWebSocketTransport producer and serves MCP queries',
      () async {
        final logBuffer = StringBuffer();
        final pipe = StreamChannelController<String>();
        final server = await LevitMcpServer.start(
          config: LevitMcpConfig(port: 0, random: Random(123)),
          channel: pipe.local,
          logSink: logBuffer,
        );

        expect(server.port, greaterThan(0));
        expect(logBuffer.toString(), contains('levit_mcp listening on'));
        expect(logBuffer.toString(), contains(server.token));

        final client = MCPClient(
          Implementation(name: 'e2e-client', version: '1.0.0'),
        );
        final connection = client.connectServer(pipe.foreign);
        await connection.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: client.capabilities,
            clientInfo: client.implementation,
          ),
        );
        connection.notifyInitialized();

        final transport = LevitWebSocketTransport.connect(
          server.wsUri.toString(),
          appId: 'e2e-app',
          token: server.token,
        );
        await transport.onConnect.first.timeout(const Duration(seconds: 3));

        await transport.send(
          LevitScopeCreateEvent(
            sessionId: 'e2e-session',
            scopeId: 42,
            scopeName: 'checkout',
            parentScopeId: null,
          ),
        );
        await transport.flush();

        final result = await connection.callTool(
          CallToolRequest(name: 'inspect_scope_tree'),
        );
        expect(result.isError, isNot(true));
        final payload =
            jsonDecode((result.content.first as TextContent).text) as Map;
        expect(payload['sessionId'], 'e2e-session');
        expect(((payload['roots'] as List).first as Map)['name'], 'checkout');

        await transport.close();
        await client.shutdown();
        await server.close();
        // Repeated close is idempotent.
        await server.close();
        await server.done;
      },
    );
  });
}
