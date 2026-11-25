import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class MockController extends LevitController {}

void main() {
  group('Snapshot dependency disposal and serialization', () {
    late LevitStateSnapshot state;
    final sid = 'test-session';

    setUp(() {
      state = LevitStateSnapshot();
    });

    test('Apply Scope Events', () {
      final event = LevitScopeCreateEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 'child',
        parentScopeId: 0,
      );
      state.applyEvent(event);
      expect(state.scopes[1]?.name, 'child');
      expect(event.toJson()['type'], 'scope_create');

      final dispose = LevitScopeDisposeEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 'child',
      );
      state.applyEvent(dispose);
      expect(dispose.toJson()['type'], 'scope_dispose');
      expect(state.scopes.containsKey(1), isFalse);

      // Test LevitConsoleTransport and serialization coverage
      final events = <LevitMonitorEvent>[
        event,
        dispose,
      ]; // Use LevitMonitorEvent
      final transport = LevitConsoleTransport();
      final rx = 0.lx; // Define rx for the transportWithOverrides part

      for (final e in events) {
        // Renamed event to e to avoid conflict
        // Just verify it doesn't crash during formatting/sending
        transport.send(e);
        // Call toJson to ensure coverage for serialization paths
        e.toJson();
      }

      // Cover overrides (line 226, 228)
      final transportWithOverrides = LevitConsoleTransport(
        levelOverrides: LevitLogLevelConfig(
          listenerAdd: LevitLogLevel.info,
          listenerRemove: LevitLogLevel.info,
        ),
      );
      transportWithOverrides.send(
        LevitReactiveListenerAddedEvent(sessionId: sid, reactive: rx),
      );
      transportWithOverrides.send(
        LevitReactiveListenerRemovedEvent(sessionId: sid, reactive: rx),
      );
      transportWithOverrides.close();
    });

    test('Apply Dependency Events', () {
      final info = LevitDependency(isLazy: true, isFactory: false);
      state.applyEvent(
        LevitDependencyRegisterEvent(
          sessionId: sid,
          scopeId: 10,
          scopeName: 'Scope10',
          key: 'DepA',
          info: info,
          source: 'put',
        ),
      );

      state.applyEvent(
        LevitDependencyInstanceReadyEvent(
          sessionId: sid,
          scopeId: 10,
          scopeName: 'Scope10',
          key: 'DepA',
          info: info,
          instance: 'InstanceVal',
        ),
      );

      // Cover model toJson
      expect(state.scopes[10]?.toJson(), isNotEmpty);
      expect(state.dependencies['10:DepA']?.toJson(), isNotEmpty);

      state.applyEvent(
        LevitDependencyDeleteEvent(
          sessionId: sid,
          scopeId: 10,
          scopeName: 'Scope10',
          key: 'DepA',
          info: info,
          source: 'delete',
        ),
      );
      expect(state.dependencies.containsKey('10:DepA'), isFalse);
    });

    test('LevitDependencyType detection', () {
      final sid = 'sid';
      state.applyEvent(
        LevitDependencyRegisterEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'ctrl',
          info: LevitDependency(),
          source: 'put',
        ),
      );

      state.applyEvent(
        LevitDependencyInstanceReadyEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'ctrl',
          info: LevitDependency(),
          instance: MockController(),
        ),
      );

      expect(
        state.dependencies['1:ctrl']?.type,
        LevitDependencyType.controller,
      );
    });

    test('Apply Reactive Events', () {
      final rx = 0.lx;
      rx.name = 'counter';
      rx.ownerId = '1:ctrl';

      state.applyEvent(LevitReactiveInitEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.toJson(), isNotEmpty);

      state.applyEvent(
        LevitReactiveListenerAddedEvent(sessionId: sid, reactive: rx),
      );
      expect(state.variables[rx.id]?.listenerCount, 1);

      // Update owner info (line 155-156)
      rx.ownerId = '2:new_ctrl';
      state.applyEvent(LevitReactiveInitEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.scopeId, 2);

      state.applyEvent(
        LevitReactiveListenerRemovedEvent(sessionId: sid, reactive: rx),
      );
      expect(state.variables[rx.id]?.listenerCount, 0);

      state.applyEvent(
        LevitReactiveChangeEvent(
          sessionId: sid,
          reactive: rx,
          change: LevitReactiveChange(
            timestamp: DateTime.now(),
            valueType: int,
            oldValue: 0,
            newValue: 1,
          ),
        ),
      );

      state.applyEvent(LevitReactiveDisposeEvent(sessionId: sid, reactive: rx));
      expect(state.variables.containsKey(rx.id), isFalse);
    });

    test('disposing a scope removes its dependencies from the snapshot', () {
      final sid = 'sid';
      state.applyEvent(
        LevitScopeCreateEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          parentScopeId: null,
        ),
      );
      state.applyEvent(
        LevitDependencyRegisterEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'k1',
          info: LevitDependency(),
          source: 'src',
        ),
      );
      expect(state.dependencies.containsKey('1:k1'), isTrue);

      state.applyEvent(
        LevitScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's1'),
      );
      expect(state.dependencies.containsKey('1:k1'), isFalse);
    });

    test('Restore from snapshot', () {
      final snapshot = {
        'scopes': [
          {'id': 1, 'name': 'root', 'parentScopeId': null},
        ],
        'dependencies': [
          {
            'scopeId': 1,
            'key': 'Dep1',
            'isLazy': false,
            'isFactory': false,
            'isAsync': false,
            'status': 'active',
            'value': 'Val1',
          },
        ],
        'variables': [
          {
            'id': 100,
            'name': 'var1',
            'ownerId': '1:ctrl',
            'value': 'hello',
            'valueType': 'String',
            'listenerCount': 5,
            'dependencies': [200],
          },
        ],
      };

      final event = LevitSnapshotEvent(sessionId: sid, state: snapshot);
      state.applyEvent(event);
      expect(event.toJson()['type'], 'snapshot');

      // Cover LevitStateSnapshot full toJson
      expect(state.toJson()['scopes'], isNotEmpty);
    });

    test('LevitReactiveModel parseOwnerId variants', () {
      final m1 = LevitReactiveModel(id: 1, name: 'n', ownerId: 'my_ctrl');
      expect(m1.toJson()['ownerKey'], 'my_ctrl');

      final m2 = LevitReactiveModel(id: 2, name: 'n', ownerId: '5:my_ctrl');
      expect(m2.scopeId, 5);
      expect(m2.toJson()['scopeId'], 5);
    });
  });
}
