import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_monitor/levit_monitor_io.dart';
import 'package:logger/logger.dart' as logger;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:levit_monitor/spi.dart';

final class _CapturePrinter extends logger.LogPrinter {
  final List<String> messages = <String>[];

  @override
  List<String> log(logger.LogEvent event) {
    messages.add(event.message.toString());
    return const <String>[];
  }
}

final class _WebSocketSink implements WebSocketSink {
  _WebSocketSink(this.controller);

  final StreamController<dynamic> controller;

  @override
  void add(dynamic data) => controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<dynamic> stream) =>
      controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done => Future<void>.value();
}

final class _WebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  final StreamController<dynamic> incoming =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> outgoing =
      StreamController<dynamic>.broadcast();

  late final _WebSocketSink _sink = _WebSocketSink(outgoing);

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => 'test';

  @override
  Future<void> get ready => Future<void>.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

LevitCustomMonitorEvent _event({
  LevitLogLevel level = LevitLogLevel.info,
  Object? error,
}) {
  return LevitCustomMonitorEvent(
    sessionId: 'session',
    namespace: 'levit.task',
    name: 'finished',
    level: level,
    attributes: const <String, Object?>{'category': 'sync'},
    error: error,
  );
}

void main() {
  test('console maps every custom level and formats errors', () {
    final printer = _CapturePrinter();
    final transport = LevitConsoleTransport(
      minLevel: LevitLogLevel.all,
      printer: printer,
    );

    expect(
      () => transport.send(_event(level: LevitLogLevel.off)),
      throwsArgumentError,
    );
    for (final level in <LevitLogLevel>[
      LevitLogLevel.fatal,
      LevitLogLevel.error,
      LevitLogLevel.warning,
      LevitLogLevel.info,
      LevitLogLevel.debug,
      LevitLogLevel.trace,
    ]) {
      transport.send(_event(level: level));
    }
    expect(
      () => transport.send(_event(level: LevitLogLevel.all)),
      throwsArgumentError,
    );
    transport.send(
      _event(level: LevitLogLevel.error, error: StateError('failed')),
    );

    expect(printer.messages, contains(contains('CUSTOM levit.task:finished')));
    expect(printer.messages.last, contains('Error: Bad state: failed'));
  });

  test('file transport categorizes custom events', () async {
    final directory = await Directory.systemTemp.createTemp('levit_custom');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/events.jsonl');
    final transport = LevitFileTransport(file.path);

    transport.send(_event());
    await transport.close();

    final payload =
        jsonDecode((await file.readAsLines()).single) as Map<String, dynamic>;
    expect(payload['category'], 'custom');
    expect(payload['type'], 'custom');
  });

  test('websocket transport categorizes custom events', () async {
    final channel = _WebSocketChannel();
    final transport = LevitWebSocketTransport(
      channel,
      requireAcknowledgement: false,
    );
    addTearDown(() async {
      await transport.close();
      await channel.incoming.close();
      await channel.outgoing.close();
    });
    final sent = channel.outgoing.stream.first;

    transport.send(_event());

    final payload = jsonDecode(await sent as String) as Map<String, dynamic>;
    expect(payload['category'], 'custom');
    expect(payload['type'], 'custom');
  });
}
