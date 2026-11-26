import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_mcp/levit_mcp.dart';
import 'package:test/test.dart';

Future<HttpClientResponse> _sendRawHttp({
  required int port,
  required String path,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
    return await request.close();
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('LevitWebSocketRelay HTTP validation and telemetry delivery', () {
    late LevitSessionStore store;
    late LevitWebSocketRelay relay;

    setUp(() async {
      store = LevitSessionStore(historyCapacity: 20);
      relay = await LevitWebSocketRelay.bind(
        config: LevitMcpConfig(
          port: 0,
          token: 'test-secret',
          maxConnections: 1,
          maxMessageBytes: 2048,
        ),
        store: store,
      );
    });

    tearDown(() async {
      await relay.close();
      // Repeated close is idempotent.
      await relay.close();
    });

    test(
      'rejects invalid Host, unknown paths, disallowed Origins, missing tokens, and non-upgrade HTTP',
      () async {
        final badHost = await _sendRawHttp(
          port: relay.port,
          path: '/ws?token=test-secret',
          headers: {HttpHeaders.hostHeader: 'evil.example:${relay.port}'},
        );
        expect(badHost.statusCode, HttpStatus.forbidden);

        final notFound = await _sendRawHttp(port: relay.port, path: '/health');
        expect(notFound.statusCode, HttpStatus.notFound);

        final badOrigin = await _sendRawHttp(
          port: relay.port,
          path: '/ws?token=test-secret',
          headers: {'Origin': 'http://evil.localhost:3000'},
        );
        expect(badOrigin.statusCode, HttpStatus.forbidden);

        final unauthorized = await _sendRawHttp(port: relay.port, path: '/ws');
        expect(unauthorized.statusCode, HttpStatus.unauthorized);

        final nonUpgrade = await _sendRawHttp(
          port: relay.port,
          path: '/ws?token=test-secret',
        );
        expect(nonUpgrade.statusCode, HttpStatus.badRequest);
      },
    );

    test(
      'accepts authenticated producer, acknowledges envelopes, enforces capacity, and marks disconnect',
      () async {
        final url = '${relay.wsUri}?appId=demo-app&token=test-secret';
        final ws = await WebSocket.connect(url);
        expect(relay.activeConnections, 1);

        // Second concurrent connection hits maxConnections (1) -> 503.
        final overCapacity = await _sendRawHttp(
          port: relay.port,
          path: '/ws?token=test-secret',
        );
        expect(overCapacity.statusCode, HttpStatus.serviceUnavailable);

        final ackCompleter = Completer<Map<String, dynamic>>();
        final sub = ws.listen((msg) {
          if (!ackCompleter.isCompleted) {
            ackCompleter.complete(
              Map<String, dynamic>.from(jsonDecode(msg as String) as Map),
            );
          }
        });

        ws.add(
          jsonEncode({
            'seq': 1,
            'sessionId': 'session-alpha',
            'category': 'di',
            'type': 'scope_create',
            'scopeId': 1,
            'scopeName': 'root',
          }),
        );

        final ack = await ackCompleter.future.timeout(
          const Duration(seconds: 2),
        );
        expect(ack['ack'], 1);
        expect(store['session-alpha']?.appId, 'demo-app');
        expect(store['session-alpha']?.connected, isTrue);
        expect(store['session-alpha']?.snapshot.scopes[1]?.name, 'root');

        await sub.cancel();
        await ws.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(store['session-alpha']?.connected, isFalse);
        expect(relay.activeConnections, 0);
      },
    );

    test(
      'assigns fallback session ID when omitted and closes sockets on invalid frames',
      () async {
        // Binary frame -> unsupportedData close.
        final wsBinary = await WebSocket.connect(
          '${relay.wsUri}',
          headers: {HttpHeaders.authorizationHeader: 'Bearer test-secret'},
        );
        wsBinary.add(<int>[1, 2, 3]);
        await wsBinary.drain<void>();
        expect(wsBinary.closeCode, WebSocketStatus.unsupportedData);

        // Oversized message -> messageTooBig close.
        final wsBig = await WebSocket.connect(
          '${relay.wsUri}?token=test-secret',
        );
        wsBig.add('x' * 3000);
        await wsBig.drain<void>();
        expect(wsBig.closeCode, WebSocketStatus.messageTooBig);

        // Non-object JSON -> policyViolation close.
        final wsBadJson = await WebSocket.connect(
          '${relay.wsUri}?token=test-secret',
        );
        wsBadJson.add(jsonEncode([1, 2, 3]));
        await wsBadJson.drain<void>();
        expect(wsBadJson.closeCode, WebSocketStatus.policyViolation);

        // Fallback sessionId when omitted.
        final wsFallback = await WebSocket.connect(
          '${relay.wsUri}?token=test-secret',
        );
        wsFallback.add(
          jsonEncode({
            'category': 'di',
            'type': 'scope_create',
            'scopeId': 9,
            'scopeName': 'anon',
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(store['session-1']?.snapshot.scopes[9]?.name, 'anon');
        await wsFallback.close();
      },
    );

    test(
      'handles stream errors and broken send/close callbacks without crashing',
      () async {
        final controller = StreamController<dynamic>();
        var closedCount = 0;

        relay.attachProducerStream(
          stream: controller.stream,
          send: (_) => throw StateError('broken pipe'),
          closeConnection: ([code]) {
            closedCount++;
            throw StateError('already closed');
          },
          appId: 'faulty-app',
        );

        controller.add(
          jsonEncode({
            'seq': 1,
            'sessionId': 'faulty-session',
            'category': 'di',
            'type': 'scope_create',
            'scopeId': 1,
            'scopeName': 'root',
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(closedCount, 1);

        controller.addError(const SocketException('reset by peer'));
        await Future<void>.delayed(Duration.zero);
        expect(store['faulty-session']?.connected, isFalse);
        expect(relay.activeConnections, 0);

        await controller.close();
      },
    );
  });
}
