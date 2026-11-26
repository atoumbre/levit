import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/src/transports/websocket_connector.dart';
import 'package:test/test.dart';

void main() {
  HttpServer? server;
  late int port;
  late Stream<dynamic> serverMessages;

  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    port = server!.port;

    final controller = StreamController<dynamic>();
    serverMessages = controller.stream.asBroadcastStream();

    server!.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
      webSocket.listen((message) {
        if (message is String) {
          try {
            final decoded = jsonDecode(message);
            controller.add(decoded);
            webSocket.add(jsonEncode({'ack': decoded['seq']}));
          } catch (_) {
            controller.add(message);
          }
        }
      });
    });
  });

  tearDown(() async {
    await LevitMonitor.detach();
    await Levit.reset(force: true);
    await server?.close(force: true);
  });

  test(
    'LevitMonitorMiddleware broadcasts DI and State events to WebSocket',
    () async {
      final transport = LevitWebSocketTransport.connect(
        'ws://127.0.0.1:$port/ws',
        appId: 'integration',
      );
      await LevitMonitor.attach(transport: transport);
      await transport.onConnect.first.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final events = <dynamic>[];
      final subscription = serverMessages.listen(events.add);
      final received = serverMessages.firstWhere(
        (event) => event['type'] == 'di_register',
      );

      final sig = 0.lx.named('test_sig');
      sig.value = 1;
      Levit.put<_TestService>(() => _TestService(), tag: 'test_tag');

      await received;
      await LevitMonitor.flush();
      await subscription.cancel();

      final registerEvent = events.firstWhere(
        (e) => e['category'] == 'di' && e['type'] == 'di_register',
        orElse: () => {},
      );
      expect(registerEvent, isNotEmpty, reason: 'DI register event not found');
      expect(registerEvent['key'], contains('_TestService_test_tag'));

      final stateEvents = events
          .where((e) => e['category'] == 'state' && e['type'] == 'state_change')
          .toList();
      expect(stateEvents, isNotEmpty, reason: 'State change event not found');
      expect(stateEvents.first['newValue'], '1');
      expect(stateEvents.first['name'], 'test_sig');

      await transport.close();
    },
  );

  test(
    'IO WebSocket connector handles failure, premature send, early close, and server disconnect',
    () async {
      // 1. Premature send before handshake completes throws StateError.
      final earlyClosed = connectWebSocket(
        Uri.parse('ws://127.0.0.1:$port/ws'),
      );
      expect(() => earlyClosed.send('too-early'), throwsStateError);
      // Close immediately while WebSocket.connect is still in flight.
      await earlyClosed.close();
      // Repeated close is idempotent.
      await earlyClosed.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. Server-initiated close completes the incoming stream cleanly.
      final shortServer = await HttpServer.bind('127.0.0.1', 0);
      shortServer.transform(WebSocketTransformer()).listen((ws) async {
        await ws.close();
      });
      final closingConn = connectWebSocket(
        Uri.parse('ws://127.0.0.1:${shortServer.port}/ws'),
      );
      await closingConn.ready;
      await closingConn.stream.drain<void>();
      await closingConn.close();
      await shortServer.close(force: true);

      // 3. Unreachable port completes `ready` with an error and closes stream.
      final deadServer = await HttpServer.bind('127.0.0.1', 0);
      final deadPort = deadServer.port;
      await deadServer.close(force: true);

      final failedConn = connectWebSocket(
        Uri.parse('ws://127.0.0.1:$deadPort/ws'),
      );
      await expectLater(failedConn.ready, throwsA(anything));
      await failedConn.stream.drain<void>();
      await failedConn.close();
    },
  );
}

class _TestService {}
