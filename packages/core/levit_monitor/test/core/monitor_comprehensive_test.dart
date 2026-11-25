import 'dart:async';
import 'dart:io';

import 'package:levit_monitor/levit_monitor_io.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ThrowingTransport extends LevitTransport {
  @override
  void send(MonitorEvent event) {}

  @override
  Future<void> close() async => throw Exception('close-fail');

  @override
  Stream<void> get onConnect => const Stream.empty();
}

class _MockWebSocketSink implements WebSocketSink {
  final StreamController<dynamic> controller;

  _MockWebSocketSink(this.controller);

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

class _MockWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final StreamController<dynamic> incoming =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> outgoing =
      StreamController<dynamic>.broadcast();
  late final _MockWebSocketSink _sink;

  _MockWebSocketChannel() {
    _sink = _MockWebSocketSink(outgoing);
  }

  @override
  Stream get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => 'test';

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();
}

void main() {
  group('Monitor filters and transport lifecycle', () {
    test(
      'monitor attaches multiple transports and accepts events through its filter',
      () async {
        final t1 = ConsoleTransport();
        final t2 = ConsoleTransport();

        await LevitMonitor.attach(transports: [t1, t2]);
        LevitMonitor.setFilter((e) => true);
        expect(
          LevitMonitor.shouldProcess(SnapshotEvent(sessionId: 's', state: {})),
          true,
        );

        await LevitMonitor.detach();
      },
    );

    test('MultiTransport reports child transport close failures', () async {
      final tThrow = ThrowingTransport();
      final multi = MultiTransport([tThrow]);
      await expectLater(multi.close(), throwsA(isA<LevitMonitorException>()));
    });

    test(
      'FileTransport accepts a snapshot and closes without connection events',
      () async {
        final file = File('test_monitor.log');
        final transport = FileTransport(file.path);

        // Cover onConnect (Line 18)
        expect(await transport.onConnect.isEmpty, true);

        final event = SnapshotEvent(sessionId: 'test', state: {'a': 1});
        transport.send(event);

        await transport.close();
        if (await file.exists()) await file.delete();
      },
    );

    test(
      'WebSocketTransport accepts a snapshot and closes its channel',
      () async {
        final transport = WebSocketTransport.connect(
          'ws://localhost:1',
          channelBuilder: (_) => _MockWebSocketChannel(),
        );

        final event = SnapshotEvent(sessionId: 'test', state: {'a': 1});
        transport.send(event);

        await transport.close();
      },
    );

    test('clearing a rejecting filter restores event processing', () {
      final event = SnapshotEvent(sessionId: 'test', state: {});
      LevitMonitor.setFilter((e) => false);
      expect(LevitMonitor.shouldProcess(event), false);
      expect(LevitMonitor.filter, isNotNull);

      LevitMonitor.setFilter(null);
      expect(LevitMonitor.shouldProcess(event), true);
    });
  });
}
