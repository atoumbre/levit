import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';

// Internal Mock Transport for this test
class MockTransport implements LevitTransport {
  final List<MonitorEvent> sentEvents = [];

  @override
  Stream<void> get onConnect => const Stream.empty();

  @override
  void send(MonitorEvent event) {
    sentEvents.add(event);
  }

  @override
  void close() {}
}

void main() {
  group('LevitMonitor Error Tracking', () {
    late MockTransport transport;

    setUp(() {
      transport = MockTransport();
      LevitMonitor.attach(transport: transport);
    });

    tearDown(() {
      LevitMonitor.detach();
      LevitReactiveMiddleware.clear();
    });

    test('Captures ReactiveErrorEvent when listener throws', () async {
      final rx = 0.lx.named('fail_rx');

      // We need to use runZonedGuarded or expectAsync because the error is caught by Levit
      // and then sent to monitor. The monitor send is synchronous in the middleware.

      rx.addListener(() {
        throw Exception('Listener Failure');
      });

      // Trigger the error (Levit catches it, so it won't crash the test)
      rx.value = 1;

      // Wait for async StreamController in LevitMonitorMiddleware to process events
      await Future.delayed(Duration.zero);

      // Assertions
      final errorEvents = transport.sentEvents.whereType<ReactiveErrorEvent>();
      expect(errorEvents, isNotEmpty);

      final errorEvent = errorEvents.first;
      expect(errorEvent.error.toString(), contains('Listener Failure'));
      expect(errorEvent.reactive?.name, equals('fail_rx'));
    });

    test('Buffer contains error event along with state change', () async {
      final rx = 0.lx;
      rx.addListener(() => throw 'Boom');

      rx.value = 1;

      await Future.delayed(Duration.zero);

      expect(transport.sentEvents.length, greaterThanOrEqualTo(2));
      expect(transport.sentEvents.any((e) => e is ReactiveChangeEvent), isTrue);
      expect(transport.sentEvents.any((e) => e is ReactiveErrorEvent), isTrue);
    });
  });
}
