import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LevitSnapshotDiagnostics', () {
    test('detects all six runtime anomaly categories from snapshot state', () {
      final snapshot = LevitStateSnapshot(maxEvents: 1, maxVariables: 2);

      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'sessionId': 's1',
          'seq': 1,
          'timestamp': '2026-11-26T00:00:00Z',
          'type': 'scope_progress',
          'category': 'di',
          'version': 1,
          'scope': [1, 'session', 1, 2, [], [], []],
        }),
      );
      snapshot.applyEnvelope(
        LevitEventEnvelope({
          'sessionId': 's1',
          'seq': 2,
          'timestamp': '2026-11-26T00:00:01Z',
          'type': 'state_init',
          'category': 'state',
          'reactiveId': '10',
          'name': 'orphan',
          'ownerId': null,
          'isSensitive': false,
          'initialValue': '0',
          'valueType': 'int',
        }),
      );
      snapshot.variables[10]!.listenerCount = 60;

      // Force variable and history eviction.
      for (final id in ['11', '12']) {
        snapshot.applyEnvelope(
          LevitEventEnvelope({
            'sessionId': 's1',
            'seq': int.parse(id),
            'timestamp': '2026-11-26T00:00:02Z',
            'type': 'state_init',
            'category': 'state',
            'reactiveId': id,
            'name': 'v$id',
            'ownerId': '1:ctrl',
            'isSensitive': false,
            'initialValue': '1',
            'valueType': 'int',
          }),
        );
      }

      final errorEnvelope = LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 20,
        'timestamp': '2026-11-26T00:00:03Z',
        'type': 'reactive_error',
        'category': 'error',
        'reactiveId': '12',
        'name': 'v12',
        'ownerId': '1:ctrl',
        'error': 'boom',
      });
      final summary = LevitSnapshotDiagnostics.extractErrorSummary(
        errorEnvelope,
      );
      expect(summary, isNotNull);
      expect(summary!['error'], 'boom');

      // Re-add orphan with high listener count after eviction.
      snapshot.variables[10] = LevitReactiveModel(id: 10, name: 'orphan')
        ..listenerCount = 60;

      final findings = LevitSnapshotDiagnostics.analyze(
        snapshot,
        recentErrors: [summary],
      );
      final codes = findings.map((f) => f.code).toSet();
      expect(
        codes,
        containsAll([
          'unowned_reactives',
          'closing_scopes',
          'pending_initializations',
          'high_listener_count',
          'recent_errors',
          'dropped_telemetry',
        ]),
      );
    });

    test('extractErrorSummary handles error logs and ignores info logs', () {
      final errorLog = LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 1,
        'timestamp': '2026-11-26T00:00:00Z',
        'type': 'log',
        'category': 'log',
        'level': 'fatal',
        'data': 'crash',
        'error': 'StateError',
      });
      final infoLog = LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 2,
        'timestamp': '2026-11-26T00:00:01Z',
        'type': 'log',
        'category': 'log',
        'level': 'info',
        'data': 'ok',
      });

      expect(
        LevitSnapshotDiagnostics.extractErrorSummary(errorLog)?['level'],
        'fatal',
      );
      expect(LevitSnapshotDiagnostics.extractErrorSummary(infoLog), isNull);
    });
  });
}
