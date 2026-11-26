import 'dart:async';
import 'dart:io';

import 'package:levit_monitor/levit_monitor_io.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class ThrowingTransport extends LevitTransport {
  @override
  void send(LevitMonitorEvent event) {}

  @override
  Future<void> close() async => throw Exception('close-fail');

  @override
  Stream<void> get onConnect => const Stream.empty();
}

class _MockWebSocketConnection implements LevitWebSocketConnection {
  final StreamController<Object?> incoming =
      StreamController<Object?>.broadcast();
  final StreamController<String> outgoing =
      StreamController<String>.broadcast();

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  void send(String data) => outgoing.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {}
}

void main() {
  group('Monitor filters and transport lifecycle', () {
    test(
      'monitor attaches multiple transports and accepts events through its filter',
      () async {
        final t1 = LevitConsoleTransport();
        final t2 = LevitConsoleTransport();

        await LevitMonitor.attach(transports: [t1, t2]);
        LevitMonitor.setFilter((e) => true);
        expect(
          LevitMonitor.shouldProcess(
            LevitSnapshotEvent(sessionId: 's', state: {}),
          ),
          true,
        );

        await LevitMonitor.detach();
      },
    );

    test(
      'LevitMultiTransport reports child transport close failures',
      () async {
        final tThrow = ThrowingTransport();
        final multi = LevitMultiTransport([tThrow]);
        await expectLater(multi.close(), throwsA(isA<LevitMonitorException>()));
      },
    );

    test(
      'LevitFileTransport accepts a snapshot and closes without connection events',
      () async {
        final file = File('test_monitor.log');
        final transport = LevitFileTransport(file.path);

        // Cover onConnect (Line 18)
        expect(await transport.onConnect.isEmpty, true);

        final event = LevitSnapshotEvent(sessionId: 'test', state: {'a': 1});
        transport.send(event);

        await transport.close();
        if (await file.exists()) await file.delete();
      },
    );

    test(
      'LevitWebSocketTransport accepts a snapshot and closes its connection',
      () async {
        final transport = LevitWebSocketTransport.connect(
          'ws://localhost:1',
          connectionBuilder: (_) => _MockWebSocketConnection(),
        );

        final event = LevitSnapshotEvent(sessionId: 'test', state: {'a': 1});
        transport.send(event);

        await transport.close();
      },
    );

    test('clearing a rejecting filter restores event processing', () {
      final event = LevitSnapshotEvent(sessionId: 'test', state: {});
      LevitMonitor.setFilter((e) => false);
      expect(LevitMonitor.shouldProcess(event), false);
      expect(LevitMonitor.filter, isNotNull);

      LevitMonitor.setFilter(null);
      expect(LevitMonitor.shouldProcess(event), true);
    });
  });
}
