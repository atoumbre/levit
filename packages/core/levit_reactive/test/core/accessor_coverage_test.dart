import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  test('Lx.enableWatchMonitoring setter works', () {
    final original = Lx.enableWatchMonitoring;
    try {
      Lx.enableWatchMonitoring = !original;
      expect(Lx.enableWatchMonitoring, !original);
    } finally {
      Lx.enableWatchMonitoring = original;
    }
  });
}
