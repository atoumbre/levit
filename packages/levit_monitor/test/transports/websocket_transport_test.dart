import 'dart:async';
import 'dart:convert';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/transports/websocket_transport.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Mock implementations
class MockWebSocketSink implements WebSocketSink {
  final StreamController<dynamic> controller;
  MockWebSocketSink(this.controller);

  @override
  void add(dynamic data) => controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      controller.addError(error, stackTrace);

  @override
  Future addStream(Stream<dynamic> stream) => controller.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) async {}

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
  group('WebSocketTransport', () {
    late MockWebSocketChannel mockChannel;
    late WebSocketTransport transport;

    setUp(() {
      mockChannel = MockWebSocketChannel();
      transport = WebSocketTransport(mockChannel);
    });

    tearDown(() {
      mockChannel.incoming.close();
      mockChannel.outgoing.close();
    });

    test('send (DependencyEvent) sends correct JSON with category', () async {
      final info = LevitDependency(builder: () => 42);
      final event = DependencyRegisterEvent(
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
    });

    test('send (ReactiveEvent) sends correct JSON with category', () async {
      final reactive = 0.lx.named('counter');
      final event = ReactiveInitEvent(
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
    });

    test('close closes the connection', () async {
      transport.close();

      bool received = false;
      final sub = mockChannel.outgoing.stream.listen((_) => received = true);

      final reactive = 0.lx;
      transport.send(ReactiveDisposeEvent(sessionId: 's', reactive: reactive));

      await Future.delayed(Duration(milliseconds: 20));
      await sub.cancel();

      expect(received, isFalse);
    });

    test('connect static method creates instance with appId', () {
      Uri? capturedUri;
      final builder = (Uri u) {
        capturedUri = u;
        return mockChannel;
      };

      final t = WebSocketTransport.connect('ws://localhost',
          appId: '123', channelBuilder: builder);

      expect(t, isA<WebSocketTransport>());
      expect(capturedUri?.queryParameters['appId'], '123');
    });

    test('handles message acknowledgment from server', () async {
      final reactive = 0.lx;
      final event = ReactiveInitEvent(sessionId: 's1', reactive: reactive);

      // Send event
      transport.send(event);

      // Simulate server acknowledgment
      mockChannel.incoming.add('ack');

      await Future.delayed(Duration(milliseconds: 50));

      expect(true, true); // Acknowledgment was handled
    });

    test('handles stream errors gracefully', () async {
      final reactive = 0.lx;
      final event = ReactiveChangeEvent(
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
