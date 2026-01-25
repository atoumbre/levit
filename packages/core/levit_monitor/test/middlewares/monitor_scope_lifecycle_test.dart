import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

import 'monitor_middleware_test.dart'; // Reuse MockTransport

void main() {
  group('LevitMonitorMiddleware Scope Lifecycle', () {
    late LevitMonitorMiddleware middleware;
    late MockTransport transport;

    setUp(() {
      transport = MockTransport();
      middleware = LevitMonitorMiddleware(transport: transport);
      middleware.enable();
    });

    tearDown(() {
      middleware.disable();
    });

    test('captures scope creation as ScopeCreateEvent', () async {
      // Create a root scope
      final rootScope = LevitScope.root('test_root');
      await Future.delayed(Duration.zero);

      final events = transport.events.whereType<ScopeCreateEvent>();
      expect(events, isNotEmpty);

      final event = events.firstWhere((e) => e.scopeName == 'test_root');
      expect(event.parentScopeId, isNull);

      // Create a child scope
      final _ = rootScope.createScope('child_scope');
      await Future.delayed(Duration.zero);

      final childEvents = transport.events
          .whereType<ScopeCreateEvent>()
          .where((e) => e.scopeName == 'child_scope');
      expect(childEvents, isNotEmpty);
      expect(childEvents.first.parentScopeId, equals(rootScope.id));
    });

    test('captures scope disposal as ScopeDisposeEvent', () async {
      final scope = LevitScope.root('disposable_scope');
      await Future.delayed(Duration.zero);

      scope.dispose();
      await Future.delayed(Duration.zero);

      final createEvent = transport.events
          .whereType<ScopeCreateEvent>()
          .firstWhere((e) => e.scopeName == 'disposable_scope');

      final disposeEvents = transport.events.whereType<ScopeDisposeEvent>();
      expect(disposeEvents, isNotEmpty);

      final event =
          disposeEvents.firstWhere((e) => e.scopeId == createEvent.scopeId);
      expect(event.scopeName, equals('disposable_scope'));
    });
  });
}
