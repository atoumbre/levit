import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_monitor/levit_monitor.dart';

class MockTransport extends LevitTransport {
  final List<MonitorEvent> sentEvents = [];
  bool isClosed = false;
  final StreamController<void> _connectController =
      StreamController<void>.broadcast();

  @override
  void send(MonitorEvent event) {
    if (isClosed) throw StateError('Transport is closed');
    sentEvents.add(event);
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await _connectController.close();
  }

  @override
  Stream<void> get onConnect => _connectController.stream;

  void simulateConnect() {
    _connectController.add(null);
  }
}

class FailingTransport extends LevitTransport {
  @override
  void send(MonitorEvent event) {
    throw Exception('Send failed');
  }

  @override
  Future<void> close() async => throw Exception('Close failed');

  @override
  Stream<void> get onConnect => const Stream.empty();
}

void main() {
  MonitorEvent createEvent() => ScopeCreateEvent(
    sessionId: 's1',
    scopeId: 1,
    scopeName: 'test',
    parentScopeId: null,
  );

  group('MultiTransport', () {
    test('broadcasts events to all transports', () async {
      final t1 = MockTransport();
      final t2 = MockTransport();
      final multi = MultiTransport([t1, t2]);
      final event = createEvent();

      await multi.send(event);

      expect(t1.sentEvents.map((event) => event.seq), contains(event.seq));
      expect(t2.sentEvents.map((event) => event.seq), contains(event.seq));
    });

    test('reports errors after attempting every transport', () async {
      final t1 = MockTransport();
      final t2 = FailingTransport(); // Should fail
      final t3 = MockTransport();
      final multi = MultiTransport([t1, t2, t3]);
      final event = createEvent();

      // Should not throw
      await expectLater(
        multi.send(event),
        throwsA(isA<LevitMonitorException>()),
      );

      expect(t1.sentEvents.map((event) => event.seq), contains(event.seq));
      expect(t3.sentEvents.map((event) => event.seq), contains(event.seq));
    });

    test('closes all transports', () async {
      final t1 = MockTransport();
      final t2 = MockTransport();
      final multi = MultiTransport([t1, t2]);

      await multi.close();

      expect(t1.isClosed, isTrue);
      expect(t2.isClosed, isTrue);
    });

    test('re-emits onConnect from any transport', () async {
      final t1 = MockTransport();
      final t2 = MockTransport();
      final multi = MultiTransport([t1, t2]);

      bool connected = false;
      final sub = multi.onConnect.listen((_) => connected = true);

      t2.simulateConnect();
      await Future.delayed(Duration.zero);

      expect(connected, isTrue);
      await sub.cancel();
    });
  });
}
