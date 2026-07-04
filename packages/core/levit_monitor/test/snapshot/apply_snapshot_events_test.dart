import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class FakeLevitStoreInstance {}

void main() {
  group('levit_monitor Final Gaps', () {
    test('snapshot.dart:82 - rehydrate dependency with type', () {
      final snapshot = StateSnapshot();
      final data = {
        'scopes': [
          {'id': 1, 'name': 'root'}
        ],
        'dependencies': [
          {
            'scopeId': 1,
            'key': 'MyService',
            'isLazy': false,
            'isFactory': false,
            'isAsync': false,
            'status': 'active',
            'type': 'controller',
            'value': 'Instance'
          }
        ],
        'variables': []
      };

      snapshot.applyEvent(SnapshotEvent(sessionId: 'abc', state: data));

      final dep = snapshot.dependencies['1:MyService']!;
      expect(dep.type, DependencyType.controller);
    });

    test('snapshot.dart:170 - detect LevitStoreInstance type', () {
      final snapshot = StateSnapshot();
      final instance = FakeLevitStoreInstance();

      final sid = 'test-session';
      final info = LevitDependency(isLazy: false, isFactory: false);

      snapshot.applyEvent(DependencyRegisterEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's1',
        key: 'MyState',
        info: info,
        source: 'test',
      ));

      snapshot.applyEvent(DependencyInstanceReadyEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's1',
        key: 'MyState',
        info: info,
        instance: instance,
      ));

      final dep = snapshot.dependencies['1:MyState']!;
      expect(dep.type, DependencyType.store);
    });
  });
}
