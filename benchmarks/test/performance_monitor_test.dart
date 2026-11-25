import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:benchmarks/performance_monitor.dart';

void main() {
  test('each measurement session unregisters both middleware hooks', () async {
    for (var round = 0; round < 3; round++) {
      final monitor = PerformanceMonitor()..enable();
      expect(monitor.isAttached, isTrue);
      final source = 0.lx;
      source.value++;
      await monitor.flush();
      expect(monitor.sink.events, greaterThan(0));
      await monitor.close();
      expect(monitor.isAttached, isFalse);
      final delivered = monitor.sink.events;
      source.value++;
      await Future<void>.delayed(Duration.zero);
      expect(monitor.sink.events, delivered);
      await Future<void>.sync(source.close);
    }
  });
}
