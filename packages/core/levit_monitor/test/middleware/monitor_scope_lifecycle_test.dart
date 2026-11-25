import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

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

    test('captures scope creation', () async {
      // Create a root scope
      final rootScope = LevitScope.root('test_root');
      await Future.delayed(Duration.zero);

      final events = transport.events.where(
        (event) => event.toJson()['type'] == 'scope_create',
      );
      expect(events, isNotEmpty);

      final event = events.firstWhere(
        (e) => e.toJson()['scopeName'] == 'test_root',
      );
      expect(event.toJson()['parentScopeId'], isNull);

      // Create a child scope
      final _ = rootScope.createScope('child_scope');
      await Future.delayed(Duration.zero);

      final childEvents = transport.events
          .where((event) => event.toJson()['type'] == 'scope_create')
          .where((e) => e.toJson()['scopeName'] == 'child_scope');
      expect(childEvents, isNotEmpty);
      expect(childEvents.first.toJson()['parentScopeId'], equals(rootScope.id));
    });

    test('captures scope disposal', () async {
      final scope = LevitScope.root('disposable_scope');
      await Future.delayed(Duration.zero);

      scope.dispose();
      await Future.delayed(Duration.zero);

      final createEvent = transport.events
          .where((event) => event.toJson()['type'] == 'scope_create')
          .firstWhere((e) => e.toJson()['scopeName'] == 'disposable_scope');

      final disposeEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'scope_dispose',
      );
      expect(disposeEvents, isNotEmpty);

      final event = disposeEvents.firstWhere(
        (e) => e.toJson()['scopeId'] == createEvent.toJson()['scopeId'],
      );
      expect(event.toJson()['scopeName'], equals('disposable_scope'));
    });
  });
}
