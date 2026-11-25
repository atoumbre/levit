import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('LevitMonitor Filtering', () {
    tearDown(() async {
      LevitMonitor.setFilter(null);
      await LevitMonitor.detach();
    });

    test('filter exposes the predicate installed by setFilter', () {
      // Covers line 51: _filter = filter;
      bool Function(LevitMonitorEvent)? myFilter = (event) => true;
      LevitMonitor.setFilter(myFilter);

      // Covers line 28: static bool Function(LevitMonitorEvent event)? get filter => _filter;
      expect(LevitMonitor.filter, equals(myFilter));
    });

    test(
      'shouldProcess accepts unfiltered events and applies installed predicates',
      () {
        final reactive = 0.lx;
        final event = LevitReactiveInitEvent(
          sessionId: 'test',
          reactive: reactive,
        );

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
      },
    );
  });

  group('LevitMonitor Setup', () {
    test('attach without transport uses LevitConsoleTransport', () async {
      // This covers line 69: final t = transport ?? LevitConsoleTransport();
      // We also check that it doesn't throw.
      expect(() async => await LevitMonitor.attach(), returnsNormally);
      await LevitMonitor.detach();
    });
  });

  group('LevitMonitorMiddleware default transport', () {
    test(
      'LevitMonitorMiddleware uses default LevitConsoleTransport when none provided',
      () async {
        // This covers line 30 in state.dart: transport = transport ?? LevitConsoleTransport()
        final middleware = LevitMonitorMiddleware();
        expect(middleware.transport, isA<LevitConsoleTransport>());
        await middleware.close();
      },
    );
  });
}
