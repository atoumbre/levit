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
  Future<void> close() async {}
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

  group('LevitMonitor transport error forwarding', () {
    test('forwards transport.send errors to current zone', () async {
      final errors = <Object>[];

      await runZonedGuarded(() async {
        final middleware = LevitMonitorMiddleware(
          transport: _ThrowingTransport(),
        );
        middleware.enable();

        final rx = 0.lx;
        rx.value = 1; // Emits ReactiveChangeEvent and triggers transport.send
        await Future<void>.delayed(Duration.zero);

        middleware.disable();
      }, (error, stackTrace) {
        errors.add(error);
      });

      expect(errors, isNotEmpty);
      expect(errors.whereType<StateError>(), isNotEmpty);
    });
  });
}

class _ThrowingTransport implements LevitTransport {
  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(MonitorEvent event) {
    throw StateError('transport failed');
  }

  @override
  Future<void> close() async {}
}
