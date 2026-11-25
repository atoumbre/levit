import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('Console event logging', () {
    test('handles all monitor events', () async {
      final transport = LevitConsoleTransport();
      final sessionId = 'test-session';
      final reactive = 0.lx;
      final scope = LevitScope.root();
      final info = LevitDependency(instance: 42);

      // Trigger LevitReactiveGraphChangeEvent log level switch case
      transport.send(
        LevitReactiveGraphChangeEvent(
          sessionId: sessionId,
          reactive: reactive,
          dependencies: [reactive],
        ),
      );

      // Trigger LevitDependencyInstanceCreateEvent log level switch case
      transport.send(
        LevitDependencyInstanceCreateEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: 'test',
          info: info,
        ),
      );

      // Trigger LevitDependencyInstanceReadyEvent log level switch case
      transport.send(
        LevitDependencyInstanceReadyEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: 'test',
          info: info,
          instance: 42,
        ),
      );

      await transport.close();
    });

    test('handles all monitor events with overrides', () async {
      final transport = LevitConsoleTransport(
        levelOverrides: const LevitLogLevelConfig(
          graphChange: LevitLogLevel.info,
          diCreate: LevitLogLevel.info,
          diInit: LevitLogLevel.info,
        ),
      );
      final sessionId = 'test-session';
      final reactive = 0.lx;
      final scope = LevitScope.root();
      final info = LevitDependency(instance: 42);

      // These will hit the 'overrides?.field' part of the expression
      transport.send(
        LevitReactiveGraphChangeEvent(
          sessionId: sessionId,
          reactive: reactive,
          dependencies: [reactive],
        ),
      );

      transport.send(
        LevitDependencyInstanceCreateEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: 'test',
          info: info,
        ),
      );

      transport.send(
        LevitDependencyInstanceReadyEvent(
          sessionId: sessionId,
          scopeId: scope.id,
          scopeName: scope.name,
          key: 'test',
          info: info,
          instance: 42,
        ),
      );

      await transport.close();
    });
  });
}
