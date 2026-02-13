import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  group('LevitTransport default close()', () {
    test('close() default implementation does nothing and does not throw',
        () async {
      final transport = MinimalTransport();

      // Call close - should not throw
      await expectLater(transport.close(), completes);

      // Can be called multiple times
      await transport.close();
      await transport.close();

      expect(true, true);
    });
  });
}

/// Minimal transport that uses default close() implementation
class MinimalTransport extends LevitTransport {
  @override
  void send(dynamic event) {
    // Minimal implementation
  }

  // Intentionally NOT overriding close() to test default implementation
}
