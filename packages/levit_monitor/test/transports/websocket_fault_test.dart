import 'dart:async';

import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/transports/websocket_transport.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockSink implements WebSocketSink {
  bool closed = false;
  final List<dynamic> sent = [];

  @override
  void add(dynamic data) {
    if (closed) throw 'Sink closed';
    sent.add(data);
  }

  @override
  Future addStream(Stream stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future get done => Future.value();
}

class _MockChannel implements WebSocketChannel {
  final _MockSink _sink = _MockSink();
  final StreamController _controller = StreamController();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _controller.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  void pipe(StreamChannel<dynamic> other) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<S> transform<S>(
      StreamChannelTransformer<S, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformSink(dynamic transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformStream(
      StreamTransformer<dynamic, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeSink(
      StreamSink<dynamic> Function(StreamSink<dynamic> sink) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<S> cast<S>() {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeStream(
      Stream<dynamic> Function(Stream<dynamic> stream) change) {
    throw UnimplementedError();
  }
}

void main() {
  group('WebSocketTransport Fault Handling', () {
    test('Handles invalid URL connection failure by scheduling reconnect',
        () async {
      int channelBuilderCalls = 0;

      final transport = WebSocketTransport.connect(
        'ws://invalid-url',
        channelBuilder: (uri) {
          channelBuilderCalls++;
          throw 'Connection failed';
        },
      );

      await Future.delayed(Duration(milliseconds: 1100));
      expect(channelBuilderCalls, greaterThanOrEqualTo(2));
      transport.close();
    });

    test('Handling disconnect during send triggers reconnect', () async {
      final mockChannel = _MockChannel();
      int connectCount = 0;

      final transport =
          WebSocketTransport.connect('ws://localhost', channelBuilder: (uri) {
        connectCount++;
        if (connectCount == 1) return mockChannel;
        return _MockChannel();
      });

      await Future.delayed(Duration(milliseconds: 10));
      mockChannel._sink.closed = true;

      final rx = 0.lx.named('test');
      transport.send(ReactiveInitEvent(sessionId: 's', reactive: rx));

      await Future.delayed(Duration(milliseconds: 1100));
      expect(connectCount, greaterThanOrEqualTo(2));
      transport.close();
    });
  });
}
