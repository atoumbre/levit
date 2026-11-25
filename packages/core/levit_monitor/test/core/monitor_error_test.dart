import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/spi.dart';

// Internal Mock Transport for this test
class MockTransport extends LevitTransport {
  final List<LevitMonitorEvent> sentEvents = [];

  @override
  Stream<void> get onConnect => const Stream.empty();

  @override
  void send(LevitMonitorEvent event) {
    sentEvents.add(event);
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('LevitMonitor Error Tracking', () {
    late MockTransport transport;

    setUp(() async {
      transport = MockTransport();
      await LevitMonitor.attach(transport: transport);
    });

    tearDown(() async {
      await LevitMonitor.detach();
      LevitReactiveMiddleware.clear();
    });

    test('Captures LevitReactiveErrorEvent when listener throws', () async {
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
      final errorEvents = transport.sentEvents.where(
        (event) => event.toJson()['type'] == 'reactive_error',
      );
      expect(errorEvents, isNotEmpty);

      final errorEvent = errorEvents.first;
      expect(
        errorEvent.toJson()['error'].toString(),
        contains('Listener Failure'),
      );
      expect(errorEvent.toJson()['name'], equals('fail_rx'));
    });

    test('Buffer contains error event along with state change', () async {
      final rx = 0.lx;
      rx.addListener(() => throw 'Boom');

      rx.value = 1;

      await Future.delayed(Duration.zero);

      expect(transport.sentEvents.length, greaterThanOrEqualTo(2));
      expect(
        transport.sentEvents.any((e) => e.toJson()['type'] == 'state_change'),
        isTrue,
      );
      expect(
        transport.sentEvents.any((e) => e.toJson()['type'] == 'reactive_error'),
        isTrue,
      );
    });
  });

  test(
    'transport failures propagate through awaited flush and cleanup',
    () async {
      final middleware = LevitMonitorMiddleware(transport: _ThrowingTransport())
        ..enable();
      final rx = 0.lx;
      rx.value = 1;
      await expectLater(
        middleware.flush(),
        throwsA(isA<LevitMonitorException>()),
      );
      await expectLater(
        middleware.close(),
        throwsA(isA<LevitMonitorException>()),
      );
      await rx.close();
    },
  );
}

class _ThrowingTransport extends LevitTransport {
  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(LevitMonitorEvent event) {
    throw StateError('transport failed');
  }

  @override
  Future<void> close() async {}
}
