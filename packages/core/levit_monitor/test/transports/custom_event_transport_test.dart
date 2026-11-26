import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_monitor/levit_monitor_io.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

final class _FakeConnection implements LevitWebSocketConnection {
  final StreamController<Object?> incoming =
      StreamController<Object?>.broadcast();
  final StreamController<String> outgoing =
      StreamController<String>.broadcast();

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  void send(String data) => outgoing.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {}
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
    final messages = <String>[];
    final transport = LevitConsoleTransport(
      minLevel: LevitLogLevel.all,
      formatter: (_, message) => message,
      output: messages.add,
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

    expect(messages, contains(contains('CUSTOM levit.task:finished')));
    expect(messages.last, contains('Error: Bad state: failed'));
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
    final connection = _FakeConnection();
    final transport = LevitWebSocketTransport(
      connection,
      requireAcknowledgement: false,
    );
    addTearDown(() async {
      await transport.close();
      await connection.incoming.close();
      await connection.outgoing.close();
    });
    final sent = connection.outgoing.stream.first;

    transport.send(_event());

    final payload = jsonDecode(await sent) as Map<String, dynamic>;
    expect(payload['category'], 'custom');
    expect(payload['type'], 'custom');
  });
}
