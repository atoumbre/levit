import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/transport.dart';
import 'package:levit_monitor/src/middlewares/state.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMonitorMiddleware close()', () {
    test('close() cleans up resources properly', () async {
      final transport = TestTransport();
      final middleware = LevitMonitorMiddleware(transport: transport);

      // Enable middleware
      middleware.enable();

      // Create some events
      final reactive = 0.lx.named('test');
      reactive.value = 1;

      await Future.delayed(Duration(milliseconds: 50));

      // Verify events were sent
      expect(transport.events.isNotEmpty, true);

      // Close middleware
      middleware.close();

      // Verify transport was closed
      expect(transport.closeCalled, true);

      // Further events should not be sent
      final eventCountBefore = transport.events.length;
      reactive.value = 2;

      await Future.delayed(Duration(milliseconds: 50));

      // Event count should not increase after close
      expect(transport.events.length, eventCountBefore);

      Levit.reset(force: true);
    });

    test('close() can be called multiple times safely', () {
      final transport = TestTransport();
      final middleware = LevitMonitorMiddleware(transport: transport);

      middleware.enable();

      // Call close multiple times
      middleware.close();
      middleware.close();
      middleware.close();

      expect(transport.closeCalled, true);
    });
  });
}

class TestTransport implements LevitTransport {
  final List<dynamic> events = [];
  bool closeCalled = false;

  @override
  void send(event) {
    if (!closeCalled) {
      events.add(event);
    }
  }

  @override
  void close() {
    closeCalled = true;
  }
}
