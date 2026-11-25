import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class FakeLevitStoreInstance {}

void main() {
  group('Snapshot dependency type reconstruction', () {
    test('snapshot events restore controller dependency types', () {
      final snapshot = LevitStateSnapshot();
      final data = {
        'scopes': [
          {'id': 1, 'name': 'root'},
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
            'value': 'Instance',
          },
        ],
        'variables': [],
      };

      snapshot.applyEvent(LevitSnapshotEvent(sessionId: 'abc', state: data));

      final dep = snapshot.dependencies['1:MyService']!;
      expect(dep.type, LevitDependencyType.controller);
    });

    test('instance-ready events classify store dependencies', () {
      final snapshot = LevitStateSnapshot();
      final instance = FakeLevitStoreInstance();

      final sid = 'test-session';
      final info = LevitDependency(isLazy: false, isFactory: false);

      snapshot.applyEvent(
        LevitDependencyRegisterEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'MyState',
          info: info,
          source: 'test',
        ),
      );

      snapshot.applyEvent(
        LevitDependencyInstanceReadyEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's1',
          key: 'MyState',
          info: info,
          instance: instance,
        ),
      );

      final dep = snapshot.dependencies['1:MyState']!;
      expect(dep.type, LevitDependencyType.store);
    });
  });
}
