import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/src/middlewares/state.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMonitor Filtering', () {
    tearDown(() {
      LevitMonitor.setFilter(null);
      LevitMonitor.detach();
    });

    test('filter getter and setter coverage', () {
      // Covers line 51: _filter = filter;
      bool Function(MonitorEvent)? myFilter = (event) => true;
      LevitMonitor.setFilter(myFilter);

      // Covers line 28: static bool Function(MonitorEvent event)? get filter => _filter;
      expect(LevitMonitor.filter, equals(myFilter));
    });

    test('shouldProcess coverage', () {
      final reactive = 0.lx;
      final event = ReactiveInitEvent(sessionId: 'test', reactive: reactive);

      // Covers line 58 part 1: _filter == null
      LevitMonitor.setFilter(null);
      expect(LevitMonitor.shouldProcess(event), isTrue);

      // Covers line 58 part 2: _filter!(event) returning true
      LevitMonitor.setFilter((e) => true);
      expect(LevitMonitor.shouldProcess(event), isTrue);

      // Covers line 58 part 2: _filter!(event) returning false
      LevitMonitor.setFilter((e) => false);
      expect(LevitMonitor.shouldProcess(event), isFalse);

      reactive.close();
    });
  });

  group('LevitMonitor Setup', () {
    test('attach without transport uses ConsoleTransport', () {
      // This covers line 69: final t = transport ?? ConsoleTransport();
      // We also check that it doesn't throw.
      expect(() => LevitMonitor.attach(), returnsNormally);
      LevitMonitor.detach();
    });
  });

  group('LevitMonitorMiddleware default transport', () {
    test(
        'LevitMonitorMiddleware uses default ConsoleTransport when none provided',
        () {
      // This covers line 30 in state.dart: transport = transport ?? ConsoleTransport()
      final middleware = LevitMonitorMiddleware();
      expect(middleware.transport, isA<ConsoleTransport>());
      middleware.close();
    });
  });
}
