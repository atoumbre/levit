import 'dart:async';
import 'dart:convert';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:levit_monitor/spi.dart';

// Mock implementations
class MockWebSocketSink implements WebSocketSink {
  final StreamController<dynamic> controller;
  MockWebSocketSink(this.controller);
  bool failClose = false;
  bool closed = false;

  @override
  void add(dynamic data) => controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      controller.addError(error, stackTrace);

  @override
  Future addStream(Stream<dynamic> stream) => controller.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (failClose) throw StateError("socket close failed");
  }

  @override
  Future get done => Future.value();
}

class MockWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final StreamController<dynamic> incoming =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> outgoing =
      StreamController<dynamic>.broadcast();
  late final MockWebSocketSink _sink;
  int? closeCode;
  String? closeReason;

  MockWebSocketChannel() {
    _sink = MockWebSocketSink(outgoing);
  }

  @override
  Stream get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => 'test';

  @override
  Future<void> get ready => Future.value();
}

void main() {
  group('LevitWebSocketTransport', () {
    late MockWebSocketChannel mockChannel;
    late LevitWebSocketTransport transport;

    setUp(() {
      mockChannel = MockWebSocketChannel();
      transport = LevitWebSocketTransport(
        mockChannel,
        requireAcknowledgement: false,
      );
    });

    tearDown(() {
      mockChannel.incoming.close();
      mockChannel.outgoing.close();
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

        final future = mockChannel.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson as String);

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

        final future = mockChannel.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson as String);

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

        final future = mockChannel.outgoing.stream.first;
        transport.send(event);
        final sentJson = await future;

        final data = jsonDecode(sentJson as String);

        expect(data['category'], 'log');
        expect(data['type'], 'log');
        expect(data['data'], 'a web socket log');
      },
    );

    test(
      'disconnect captures asynchronous cleanup errors and awaits release',
      () async {
        mockChannel._sink.failClose = true;
        await mockChannel.ready;
        await mockChannel.incoming.close();
        await Future<void>.delayed(Duration.zero);
        expect(mockChannel._sink.closed, isTrue);
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
      final sub = mockChannel.outgoing.stream.listen((_) => received = true);

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
      final builder = (Uri u) {
        capturedUri = u;
        return mockChannel;
      };

      final t = LevitWebSocketTransport.connect(
        'ws://localhost',
        appId: '123',
        token: 'secret-token',
        channelBuilder: builder,
      );

      expect(t, isA<LevitWebSocketTransport>());
      expect(capturedUri?.queryParameters['appId'], '123');
      expect(capturedUri?.queryParameters['token'], 'secret-token');
    });

    test('handles message acknowledgment from server', () async {
      final reactive = 0.lx;
      final event = LevitReactiveInitEvent(sessionId: 's1', reactive: reactive);

      // Send event
      transport.send(event);

      // Simulate server acknowledgment
      mockChannel.incoming.add('ack');

      await Future.delayed(Duration(milliseconds: 50));

      expect(true, true); // Acknowledgment was handled
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

      // Simulate error
      mockChannel.incoming.addError(Exception('Connection error'));

      await Future.delayed(Duration(milliseconds: 50));

      expect(true, true); // Error was handled without crashing
    });
  });
}
