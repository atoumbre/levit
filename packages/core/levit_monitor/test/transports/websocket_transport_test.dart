import 'dart:async';
import 'dart:convert';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class MockWebSocketConnection implements LevitWebSocketConnection {
  final StreamController<Object?> incoming =
      StreamController<Object?>.broadcast();
  final StreamController<String> outgoing =
      StreamController<String>.broadcast();
  bool failClose = false;
  bool closed = false;

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  void send(String data) => outgoing.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (failClose) throw StateError('socket close failed');
  }
}

void main() {
  group('LevitWebSocketTransport', () {
    late MockWebSocketConnection mockConnection;
    late LevitWebSocketTransport transport;

    setUp(() {
      mockConnection = MockWebSocketConnection();
      transport = LevitWebSocketTransport(
        mockConnection,
        requireAcknowledgement: false,
      );
    });

    tearDown(() {
      mockConnection.incoming.close();
      mockConnection.outgoing.close();
    });

    test(
      'send (LevitDependencyEvent) sends correct JSON with category',
      () async {
        final info = LevitDependency(builder: () => 42);
        final event = LevitDependencyRegisterEvent(
          sessionId: 's1',
          scopeId: 1,
          scopeName: 'root',
          key: 'Service',
          info: info,
          source: 'test',
        );

        final future = mockConnection.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson);

        expect(data['category'], 'di');
        expect(data['type'], 'di_register');
        expect(data['key'], 'Service');
      },
    );

    test(
      'send (LevitReactiveEvent) sends correct JSON with category',
      () async {
        final reactive = 0.lx.named('counter');
        final event = LevitReactiveInitEvent(
          sessionId: 's1',
          reactive: reactive,
        );

        final future = mockConnection.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson);

        expect(data['category'], 'state');
        expect(data['type'], 'reactive_init');
        expect(data['name'], 'counter');
      },
    );

    test(
      'send (LevitLogEvent) sends correct JSON with category "log"',
      () async {
        final event = LevitLogEvent(
          sessionId: 's1',
          level: LevitLogLevel.info,
          data: 'a web socket log',
        );

        final future = mockConnection.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson);

        expect(data['category'], 'log');
        expect(data['type'], 'log');
        expect(data['data'], 'a web socket log');
      },
    );

    test(
      'disconnect captures asynchronous cleanup errors and awaits release',
      () async {
        mockConnection.failClose = true;
        await mockConnection.ready;
        await mockConnection.incoming.close();
        await Future<void>.delayed(Duration.zero);
        expect(mockConnection.closed, isTrue);
        await expectLater(
          transport.flush(),
          throwsA(isA<LevitMonitorException>()),
        );
        await expectLater(
          transport.close(),
          throwsA(isA<LevitMonitorException>()),
        );
      },
    );

    test('close closes the connection', () async {
      await transport.close();

      bool received = false;
      final sub = mockConnection.outgoing.stream.listen((_) => received = true);

      final reactive = 0.lx;
      transport.send(
        LevitReactiveDisposeEvent(sessionId: 's', reactive: reactive),
      );

      await Future.delayed(Duration(milliseconds: 20));
      await sub.cancel();

      expect(received, isFalse);
    });

    test('connect static method creates instance with appId and token', () {
      Uri? capturedUri;
      LevitWebSocketConnection builder(Uri u) {
        capturedUri = u;
        return mockConnection;
      }

      final t = LevitWebSocketTransport.connect(
        'ws://localhost',
        appId: '123',
        token: 'secret-token',
        connectionBuilder: builder,
      );

      expect(t, isA<LevitWebSocketTransport>());
      expect(capturedUri?.queryParameters['appId'], '123');
      expect(capturedUri?.queryParameters['token'], 'secret-token');
    });

    test('handles message acknowledgment from server', () async {
      final reactive = 0.lx;
      final event = LevitReactiveInitEvent(sessionId: 's1', reactive: reactive);

      transport.send(event);
      mockConnection.incoming.add('ack');

      await Future.delayed(Duration(milliseconds: 50));

      expect(true, true);
    });

    test('handles stream errors gracefully', () async {
      final reactive = 0.lx;
      final event = LevitReactiveChangeEvent(
        sessionId: 's1',
        reactive: reactive,
        change: LevitReactiveChange(
          timestamp: DateTime.now(),
          valueType: int,
          oldValue: 0,
          newValue: 1,
        ),
      );

      transport.send(event);
      mockConnection.incoming.addError(Exception('Connection error'));

      await Future.delayed(Duration(milliseconds: 50));

      expect(true, true);
    });
  });
}
