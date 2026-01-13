import 'package:levit_monitor/src/core/transport.dart';
import 'package:test/test.dart';

void main() {
  group('LevitTransport default close()', () {
    test('close() default implementation does nothing and does not throw', () {
      final transport = MinimalTransport();

      // Call close - should not throw
      expect(() => transport.close(), returnsNormally);

      // Can be called multiple times
      transport.close();
      transport.close();

      expect(true, true);
    });
  });
}

/// Minimal transport that uses default close() implementation
class MinimalTransport extends LevitTransport {
  @override
  void send(event) {
    // Minimal implementation
  }

  // Intentionally NOT overriding close() to test default implementation
}
