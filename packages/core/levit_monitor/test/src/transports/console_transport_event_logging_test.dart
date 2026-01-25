import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

import 'package:test/test.dart';

void main() {
  group('ConsoleTransport Coverage', () {
    test('handles all monitor events', () {
      final transport = ConsoleTransport();
      final sessionId = 'test-session';
      final reactive = 0.lx;
      final scope = LevitScope.root();
      final info = LevitDependency(instance: 42);

      // Trigger ReactiveGraphChangeEvent log level switch case
      transport.send(ReactiveGraphChangeEvent(
        sessionId: sessionId,
        reactive: reactive,
        dependencies: [reactive],
      ));

      // Trigger DependencyInstanceCreateEvent log level switch case
      transport.send(DependencyInstanceCreateEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: 'test',
        info: info,
      ));

      // Trigger DependencyInstanceReadyEvent log level switch case
      transport.send(DependencyInstanceReadyEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: 'test',
        info: info,
        instance: 42,
      ));

      transport.close();
    });

    test('handles all monitor events with overrides', () {
      final transport = ConsoleTransport(
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
      transport.send(ReactiveGraphChangeEvent(
        sessionId: sessionId,
        reactive: reactive,
        dependencies: [reactive],
      ));

      transport.send(DependencyInstanceCreateEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: 'test',
        info: info,
      ));

      transport.send(DependencyInstanceReadyEvent(
        sessionId: sessionId,
        scopeId: scope.id,
        scopeName: scope.name,
        key: 'test',
        info: info,
        instance: 42,
      ));

      transport.close();
    });
  });
}
