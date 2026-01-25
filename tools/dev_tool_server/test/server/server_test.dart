import 'dart:convert';

import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late DevToolController server;
  const int port = 9201; // Use a different port for testing

  setUp(() async {
    server = DevToolController(port: port);
    await server.start();
  });

  tearDown(() async {
    await server.stop();
  });

  test('Server accepts connection and creates AppSession', () async {
    final channel = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:$port'),
    );

    // Wait for connection to be established (implicitly)

    // Wait for connection to be established (implicitly)

    // Wait for the first session to appear in the map
    final sessionFuture = server.sessions.stream
        .map(
          (sessions) => sessions.values.isEmpty ? null : sessions.values.first,
        )
        .where((s) => s != null)
        .cast<AppSession>()
        .first;

    // Send a message
    final event = {
      'type': 'reactive_init',
      'sessionId': 'test-session-1',
      'reactiveId': '1',
      'name': 'counter',
      'ownerId': 'main',
      'initialValue': 0,
      'valueType': 'int',
      'timestamp': DateTime.now().toIso8601String(),
      'seq': 1,
    };
    channel.sink.add(jsonEncode(event));

    final session = await sessionFuture.timeout(Duration(seconds: 2));
    expect(session.sessionId, equals('test-session-1'));
    expect(session.state.variables.length, equals(1));
    expect(session.state.variables[1]?.name, equals('counter'));

    await channel.sink.close();
  });

  test('Server handles multiple sessions', () async {
    // onSessionUpdate is now broadcast by default if using stream on StreamController
    // But we removed `onSessionUpdate` getter in new implementation?
    // The previous implementation had `Stream<AppSession> get onSessionUpdate`.
    // In new impl I removed it? Let's check `dev_tool_server.dart`.
    // I likely need to re-add it or use `sessions.stream`.
    // LxMap doesn't expose stream of "additions" easily like that, but LxMap.stream emits map changes.
    // For this test, I will need to verify if `onSessionUpdate` still exists or if I need to listen to `server.sessions`.

    // Assuming I removed onSessionUpdate in previous refactor step where I replaced class def.
    // I should check dev_tool_server.dart content first or assume I need to fix it.
    // Let's use `server.sessions.stream` and detect changes.

    final _ = server.sessions.stream;

    // Client 1
    final channel1 = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:$port'),
    );
    channel1.sink.add(
      jsonEncode({
        'type':
            'reactive_alloc', // Using a dummy type just to trigger session creation
        'sessionId': 'session-A',
        'timestamp': DateTime.now().toIso8601String(),
        'seq': 1,
      }),
    );

    // Client 2
    final channel2 = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:$port'),
    );
    channel2.sink.add(
      jsonEncode({
        'type': 'reactive_alloc',
        'sessionId': 'session-B',
        'timestamp': DateTime.now().toIso8601String(),
        'seq': 1,
      }),
    );

    // The stream emits Map events. We wait for 2 sessions to be in the map.
    // Simplifying test to just poll or wait for condition.

    await Future.delayed(
      Duration(seconds: 1),
    ); // Simple wait for async processing

    expect(server.sessions.length, equals(2));
    expect(server.sessions.keys, containsAll(['session-A', 'session-B']));

    await channel1.sink.close();
    await channel2.sink.close();
  });
}
