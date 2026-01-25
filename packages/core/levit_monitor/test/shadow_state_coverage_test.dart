import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class MockController extends LevitController {}

void main() {
  group('StateSnapshot Coverage', () {
    late StateSnapshot state;
    final sid = 'test-session';

    setUp(() {
      state = StateSnapshot();
    });

    test('Apply Scope Events', () {
      final event = ScopeCreateEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 'child',
        parentScopeId: 0,
      );
      state.applyEvent(event);
      expect(state.scopes[1]?.name, 'child');
      expect(event.toJson()['type'], 'scope_create');

      final dispose = ScopeDisposeEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 'child',
      );
      state.applyEvent(dispose);
      expect(dispose.toJson()['type'], 'scope_dispose');
      expect(state.scopes.containsKey(1), isFalse);

      // Test ConsoleTransport and serialization coverage
      final events = <MonitorEvent>[event, dispose]; // Use MonitorEvent
      final transport = ConsoleTransport();
      final rx = 0.lx; // Define rx for the transportWithOverrides part

      for (final e in events) {
        // Renamed event to e to avoid conflict
        // Just verify it doesn't crash during formatting/sending
        transport.send(e);
        // Call toJson to ensure coverage for serialization paths
        e.toJson();
      }

      // Cover overrides (line 226, 228)
      final transportWithOverrides = ConsoleTransport(
        levelOverrides: LevitLogLevelConfig(
          listenerAdd: LevitLogLevel.info,
          listenerRemove: LevitLogLevel.info,
        ),
      );
      transportWithOverrides
          .send(ReactiveListenerAddedEvent(sessionId: sid, reactive: rx));
      transportWithOverrides
          .send(ReactiveListenerRemovedEvent(sessionId: sid, reactive: rx));
      transportWithOverrides.close();
    });

    test('Apply Dependency Events', () {
      final info = LevitDependency(isLazy: true, isFactory: false);
      state.applyEvent(DependencyRegisterEvent(
        sessionId: sid,
        scopeId: 10,
        scopeName: 'Scope10',
        key: 'DepA',
        info: info,
        source: 'put',
      ));

      state.applyEvent(DependencyInstanceReadyEvent(
        sessionId: sid,
        scopeId: 10,
        scopeName: 'Scope10',
        key: 'DepA',
        info: info,
        instance: 'InstanceVal',
      ));

      // Cover model toJson
      expect(state.scopes[10]?.toJson(), isNotEmpty);
      expect(state.dependencies['10:DepA']?.toJson(), isNotEmpty);

      state.applyEvent(DependencyDeleteEvent(
        sessionId: sid,
        scopeId: 10,
        scopeName: 'Scope10',
        key: 'DepA',
        info: info,
        source: 'delete',
      ));
      expect(state.dependencies.containsKey('10:DepA'), isFalse);
    });

    test('DependencyType detection', () {
      final sid = 'sid';
      state.applyEvent(DependencyRegisterEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's1',
        key: 'ctrl',
        info: LevitDependency(),
        source: 'put',
      ));

      state.applyEvent(DependencyInstanceReadyEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's1',
        key: 'ctrl',
        info: LevitDependency(),
        instance: MockController(),
      ));

      expect(state.dependencies['1:ctrl']?.type, DependencyType.controller);
    });

    test('Apply Reactive Events', () {
      final rx = 0.lx;
      rx.name = 'counter';
      rx.ownerId = '1:ctrl';

      state.applyEvent(ReactiveInitEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.toJson(), isNotEmpty);

      state
          .applyEvent(ReactiveListenerAddedEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.listenerCount, 1);

      // Update owner info (line 155-156)
      rx.ownerId = '2:new_ctrl';
      state.applyEvent(ReactiveInitEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.scopeId, 2);

      state.applyEvent(
          ReactiveListenerRemovedEvent(sessionId: sid, reactive: rx));
      expect(state.variables[rx.id]?.listenerCount, 0);

      state.applyEvent(ReactiveChangeEvent(
        sessionId: sid,
        reactive: rx,
        change: LevitReactiveChange(
          timestamp: DateTime.now(),
          valueType: int,
          oldValue: 0,
          newValue: 1,
        ),
      ));

      state.applyEvent(ReactiveDisposeEvent(sessionId: sid, reactive: rx));
      expect(state.variables.containsKey(rx.id), isFalse);
    });

    test('Scope disposal with dependencies (line 107)', () {
      final sid = 'sid';
      state.applyEvent(ScopeCreateEvent(
          sessionId: sid, scopeId: 1, scopeName: 's1', parentScopeId: null));
      state.applyEvent(DependencyRegisterEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'k1',
          info: LevitDependency(),
          source: 'src'));
      expect(state.dependencies.containsKey('1:k1'), isTrue);

      state.applyEvent(
          ScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's1'));
      expect(state.dependencies.containsKey('1:k1'), isFalse);
    });

    test('Restore from snapshot', () {
      final snapshot = {
        'scopes': [
          {'id': 1, 'name': 'root', 'parentScopeId': null}
        ],
        'dependencies': [
          {
            'scopeId': 1,
            'key': 'Dep1',
            'isLazy': false,
            'isFactory': false,
            'isAsync': false,
            'status': 'active',
            'value': 'Val1'
          }
        ],
        'variables': [
          {
            'id': 100,
            'name': 'var1',
            'ownerId': '1:ctrl',
            'value': 'hello',
            'valueType': 'String',
            'listenerCount': 5,
            'dependencies': [200]
          }
        ]
      };

      final event = SnapshotEvent(sessionId: sid, state: snapshot);
      state.applyEvent(event);
      expect(event.toJson()['type'], 'snapshot');

      // Cover StateSnapshot full toJson
      expect(state.toJson()['scopes'], isNotEmpty);
    });

    test('ReactiveModel parseOwnerId variants', () {
      final m1 = ReactiveModel(id: 1, name: 'n', ownerId: 'my_ctrl');
      expect(m1.toJson()['ownerKey'], 'my_ctrl');

      final m2 = ReactiveModel(id: 2, name: 'n', ownerId: '5:my_ctrl');
      expect(m2.scopeId, 5);
      expect(m2.toJson()['scopeId'], 5);
    });
  });
}
