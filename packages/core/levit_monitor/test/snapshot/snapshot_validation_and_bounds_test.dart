import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LevitStateSnapshot validation and bounds', () {
    test('rejects non-positive maxVariables', () {
      expect(
        () => LevitStateSnapshot(maxVariables: 0),
        throwsA(isA<RangeError>()),
      );
    });

    test('validates scope_progress records eagerly without mutating state', () {
      final snapshot = LevitStateSnapshot(maxEvents: 5);

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': 'not-a-list',
          }),
        ),
        throwsFormatException,
      );

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': ['bad-id', 'root', 0, 0, [], [], []],
          }),
        ),
        throwsFormatException,
      );

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': [
              1,
              'root',
              0,
              0,
              [
                ['bad-parent', 'p'],
              ],
              [],
              [],
            ],
          }),
        ),
        throwsFormatException,
      );

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': [
              1,
              'root',
              0,
              0,
              [],
              [
                [2],
              ],
              [],
            ],
          }),
        ),
        throwsFormatException,
      );

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': [
              1,
              'root',
              0,
              0,
              [],
              [],
              [
                ['k', 'T', 123, 0, 0, 0],
              ],
            ],
          }),
        ),
        throwsFormatException,
      );

      expect(snapshot.scopes, isEmpty);
      expect(snapshot.events, isEmpty);
    });

    test('restores snapshot atomically and preserves prior state on error', () {
      final snapshot = LevitStateSnapshot();
      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'scope_create',
          'scopeId': 1,
          'scopeName': 'root',
        }),
      );

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({'type': 'snapshot', 'state': 'invalid'}),
        ),
        throwsFormatException,
      );
      expect(snapshot.scopes.containsKey(1), isTrue);

      expect(
        () => snapshot.applyEnvelope(
          LevitEventEnvelope({
            'type': 'snapshot',
            'state': {
              'scopes': [
                {'id': 2, 'name': 'next'},
              ],
              'dependencies': [
                {
                  'scopeId': 2,
                  'key': 'k',
                  'isLazy': false,
                  'isFactory': false,
                  'isAsync': false,
                  'status': 'not_a_status',
                },
              ],
            },
          }),
        ),
        throwsArgumentError,
      );
      expect(snapshot.scopes.keys, equals([1]));
    });

    test('prunes scope variables on scope_dispose and caps maxVariables', () {
      final snapshot = LevitStateSnapshot(maxVariables: 2);

      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'scope_create',
          'scopeId': 10,
          'scopeName': 'feature',
        }),
      );
      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'reactive_init',
          'reactiveId': 1,
          'name': 'a',
          'ownerId': '10:ctrl',
          'initialValue': 1,
        }),
      );
      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'reactive_init',
          'reactiveId': 2,
          'name': 'b',
          'ownerId': '20:other',
          'initialValue': 2,
        }),
      );
      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'reactive_init',
          'reactiveId': 3,
          'name': 'c',
          'ownerId': '10:ctrl',
          'initialValue': 3,
        }),
      );

      expect(snapshot.variables.keys, equals([2, 3]));
      expect(snapshot.droppedVariables, 1);

      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'scope_dispose',
          'scopeId': 10,
          'scopeName': 'feature',
        }),
      );
      expect(snapshot.variables.keys, equals([2]));

      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'type': 'snapshot',
          'state': {
            'variables': [
              {'id': 11, 'name': 'v1'},
              {'id': 12, 'name': 'v2'},
              {'id': 13, 'name': 'v3'},
            ],
          },
        }),
      );
      expect(snapshot.variables.keys, equals([12, 13]));
      expect(snapshot.droppedVariables, 1);
      expect(snapshot.toJson()['droppedVariables'], 1);
    });
  });
}
