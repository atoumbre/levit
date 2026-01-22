import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  HttpServer? server;
  late int port;
  late Stream<dynamic> serverMessages;

  setUp(() async {
    // 1. Start a real WebSocket server
    server = await HttpServer.bind('localhost', 0);
    port = server!.port;

    final controller = StreamController<dynamic>();
    serverMessages = controller.stream.asBroadcastStream();

    server!.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
      webSocket.listen((message) {
        if (message is String) {
          try {
            final decoded = jsonDecode(message);
            controller.add(decoded);
          } catch (_) {
            controller.add(message);
          }
        }
      });
    });
  });

  tearDown(() async {
    LevitMonitor.detach();
    Levit.reset(force: true);
    await server?.close(force: true);
  });

  test('LevitMonitorMiddleware broadcasts DI and State events to WebSocket',
      () async {
    // 2. Connect client
    final channel = IOWebSocketChannel.connect('ws://localhost:$port/ws');
    final transport = WebSocketTransport(channel);

    // 3. Attach Monitor
    LevitMonitor.attach(transport: transport);

    // 4. Trigger Events
    // A. Reactive Event
    final sig = 0.lx.named('test_sig');
    sig.value = 1;

    // B. DI Event
    Levit.put<_TestService>(() => _TestService(), tag: 'test_tag');

    // 5. Verify Server Received
    // We expect events for:
    // - ReactiveInit (test_sig)
    // - StateChange (test_sig: 0 -> 1)
    // - DIRegister (_TestService)

    print('Waiting for events...');
    final events = await serverMessages.take(4).toList();
    print('Received ${events.length} events:');
    for (var e in events) {
      print(
          '  - Category: ${e['category']}, Type: ${e['type']}, Key/Name: ${e['key'] ?? e['name']}');
    }

    // Verify DI Event
    final registerEvent = events.firstWhere(
        (e) => e['category'] == 'di' && e['type'] == 'di_register',
        orElse: () => {});

    expect(registerEvent, isNotEmpty, reason: 'DI register event not found');
    expect(registerEvent['key'], contains('_TestService_test_tag'));

    // Verify State Event (Update)
    final stateEvents = events
        .where((e) => e['category'] == 'state' && e['type'] == 'state_change')
        .toList();
    expect(stateEvents, isNotEmpty, reason: 'State change event not found');

    final updateEvent = stateEvents.first;
    expect(updateEvent['newValue'], '1');
    expect(updateEvent['name'], 'test_sig');

    transport.close();
  });
}

class _TestService {}
