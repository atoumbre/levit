import 'dart:io';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class ThrowingTransport implements LevitTransport {
  @override
  void send(MonitorEvent event) {}

  @override
  void close() => throw Exception('close-fail');

  @override
  Stream<void> get onConnect => const Stream.empty();
}

void main() {
  group('LevitMonitor Comprehensive', () {
    test('attach with multiple transports and MultiTransport coverage', () {
      final t1 = ConsoleTransport();
      final t2 = ConsoleTransport();

      LevitMonitor.attach(transports: [t1, t2]);
      LevitMonitor.setFilter((e) => true);
      expect(
          LevitMonitor.shouldProcess(SnapshotEvent(sessionId: 's', state: {})),
          true);

      LevitMonitor.detach();
    });

    test('MultiTransport close error coverage', () {
      final tThrow = ThrowingTransport();
      final multi = MultiTransport([tThrow]);
      multi.close();
    });

    test('FileTransport and SnapshotEvent coverage', () async {
      final file = File('test_monitor.log');
      final transport = FileTransport(file.path);

      // Cover onConnect (Line 18)
      expect(await transport.onConnect.isEmpty, true);

      final event = SnapshotEvent(sessionId: 'test', state: {'a': 1});
      transport.send(event);

      transport.close();
      if (await file.exists()) await file.delete();
    });

    test('WebSocketTransport SnapshotEvent coverage', () {
      final transport = WebSocketTransport.connect('ws://localhost:1');

      final event = SnapshotEvent(sessionId: 'test', state: {'a': 1});
      transport.send(event);

      transport.close();
    });

    test('LevitMonitor filter coverage', () {
      final event = SnapshotEvent(sessionId: 'test', state: {});
      LevitMonitor.setFilter((e) => false);
      expect(LevitMonitor.shouldProcess(event), false);
      expect(LevitMonitor.filter, isNotNull);

      LevitMonitor.setFilter(null);
      expect(LevitMonitor.shouldProcess(event), true);
    });
  });
}
