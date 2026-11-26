import 'package:levit_mcp/levit_mcp.dart';
import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

void main() {
  group('LevitRuntimeDiagnostics anomaly detection', () {
    test('returns empty findings for a clean session', () {
      final store = LevitSessionStore(historyCapacity: 10);
      store.applyEnvelope(
        's1',
        LevitEventEnvelope({
          'type': 'scope_create',
          'scopeId': 1,
          'scopeName': 'root',
        }),
      );
      store.applyEnvelope(
        's1',
        LevitEventEnvelope({
          'type': 'reactive_init',
          'reactiveId': 1,
          'name': 'count',
          'ownerId': '1:CounterController',
          'initialValue': 0,
        }),
      );

      final findings = LevitRuntimeDiagnostics.analyze(store['s1']!);
      expect(findings, isEmpty);
    });

    test(
      'flags unowned reactives, closing scopes, pending init, high listeners, errors, and drops',
      () {
        final store = LevitSessionStore(historyCapacity: 1, maxVariables: 2);
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'type': 'scope_progress',
            'version': 1,
            'scope': [
              1,
              'feature',
              1, // isClosing = true
              2, // pendingInitializations = 2
              [],
              [],
              [],
            ],
          }),
        );
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'type': 'reactive_init',
            'reactiveId': 10,
            'name': 'evicted',
            'ownerId': '1:ctrl',
            'initialValue': 0,
          }),
        );
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'type': 'reactive_init',
            'reactiveId': 11,
            'name': 'orphanVar',
            'initialValue': 1,
          }),
        );
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'type': 'reactive_init',
            'reactiveId': 12,
            'name': 'hotVar',
            'ownerId': '1:ctrl',
            'initialValue': 2,
          }),
        );
        for (var i = 0; i < 3; i++) {
          store.applyEnvelope(
            's1',
            LevitEventEnvelope({'type': 'listener_add', 'reactiveId': 12}),
          );
        }
        store.applyEnvelope(
          's1',
          LevitEventEnvelope({
            'seq': 99,
            'type': 'reactive_error',
            'reactiveId': 12,
            'name': 'hotVar',
            'error': 'StateError: boom',
          }),
        );

        final findings = LevitRuntimeDiagnostics.analyze(
          store['s1']!,
          highListenerThreshold: 3,
        );
        final codes = findings.map((f) => f.code).toSet();
        expect(
          codes,
          containsAll({
            'unowned_reactives',
            'closing_scopes',
            'pending_initializations',
            'high_listener_count',
            'recent_errors',
            'dropped_telemetry',
          }),
        );
        for (final finding in findings) {
          final json = finding.toJson();
          expect(json['code'], finding.code);
          expect(json['severity'], finding.severity.name);
          expect(json['details'], isNotEmpty);
        }
      },
    );
  });
}
