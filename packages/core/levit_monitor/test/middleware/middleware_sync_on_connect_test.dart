import 'dart:async';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('LevitMonitorMiddleware', () {
    test('snapshot sync on connect', () async {
      final transport = MockTransport();
      final middleware = LevitMonitorMiddleware(transport: transport);

      middleware.enable();
      transport.onConnectController.add(null);

      await Future.delayed(Duration(milliseconds: 10));
      expect(
        transport.sentEvents.any((e) => e.toJson()['type'] == 'snapshot'),
        isTrue,
      );

      middleware.disable();
      await middleware.close();
    });
  });
}

class MockTransport extends LevitTransport {
  final sentEvents = <LevitMonitorEvent>[];
  final onConnectController = StreamController<void>.broadcast();

  @override
  void send(LevitMonitorEvent event) => sentEvents.add(event);

  @override
  Stream<void> get onConnect => onConnectController.stream;

  @override
  Future<void> close() async {
    await onConnectController.close();
  }
}
