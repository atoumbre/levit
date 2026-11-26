part of 'monitor_library.dart';

/// Severity level for a runtime diagnostic finding.
///
/// {@category SPI}
enum LevitDiagnosticSeverity {
  /// Informational observation (for example in-flight async initializations or
  /// bounded telemetry drops).
  info,

  /// Potential lifecycle or leak anomaly that should be investigated (for
  /// example unowned reactives, closing scopes, or high listener counts).
  warning,

  /// Captured runtime error event requiring immediate attention.
  error,
}

/// A single deterministic runtime finding produced by [LevitSnapshotDiagnostics].
///
/// {@category SPI}
final class LevitDiagnosticFinding {
  /// Stable machine-readable finding code.
  final String code;

  /// Finding severity.
  final LevitDiagnosticSeverity severity;

  /// Human-readable summary of the detected condition.
  final String message;

  /// Structured evidence payload for inspectors and agents.
  final Map<String, dynamic> details;

  /// Creates a diagnostic finding.
  const LevitDiagnosticFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.details = const {},
  });

  /// Serializes this finding to JSON.
  Map<String, dynamic> toJson() => {
    'code': code,
    'severity': severity.name,
    'message': message,
    if (details.isNotEmpty) 'details': details,
  };
}

/// Deterministic runtime anomaly analyzer operating on [LevitStateSnapshot].
///
/// Shared by `levit_mcp`, `levit_devtools`, and custom inspectors so AI agents
/// and visual DevTools tabs report identical finding codes and thresholds.
///
/// {@category SPI}
abstract final class LevitSnapshotDiagnostics {
  /// Default threshold above which a reactive's listener count triggers a warning.
  static const int defaultHighListenerThreshold = 50;

  /// Extracts a compact redacted error summary map if [envelope] represents a
  /// `reactive_error` event or an `error`/`fatal` log entry; otherwise returns
  /// `null`.
  static Map<String, dynamic>? extractErrorSummary(
    LevitEventEnvelope envelope,
  ) {
    final data = envelope.data;
    if (envelope.type == 'reactive_error') {
      return {
        'seq': envelope.seq,
        'timestamp': data['timestamp'],
        'type': envelope.type,
        'reactiveId': data['reactiveId'],
        'name': data['name'],
        'ownerId': data['ownerId'],
        'error': data['error'],
      };
    }
    if (envelope.type == 'log') {
      final level = data['level']?.toString().toLowerCase();
      if (level == 'error' || level == 'fatal') {
        return {
          'seq': envelope.seq,
          'timestamp': data['timestamp'],
          'type': envelope.type,
          'level': data['level'],
          'data': data['data'],
          'error': data['error'],
        };
      }
    }
    return null;
  }

  /// Runs all six built-in deterministic diagnostic checks against [snapshot]
  /// and optional [recentErrors].
  ///
  /// Checks:
  /// - `unowned_reactives` ([LevitDiagnosticSeverity.warning]): Reactives with
  ///   a missing, empty, or `'?'` `ownerId`.
  /// - `closing_scopes` ([LevitDiagnosticSeverity.warning]): Scopes currently
  ///   stuck in `isClosing == true`.
  /// - `pending_initializations` ([LevitDiagnosticSeverity.info]): Scopes with
  ///   in-flight async initializations (`pendingInitializations > 0`).
  /// - `high_listener_count` ([LevitDiagnosticSeverity.warning]): Reactives
  ///   whose active listener count is `>=` [highListenerThreshold] (defaults to
  ///   [defaultHighListenerThreshold]).
  /// - `recent_errors` ([LevitDiagnosticSeverity.error]): Captured
  ///   `reactive_error` events or `error`/`fatal` log entries.
  /// - `dropped_telemetry` ([LevitDiagnosticSeverity.info]): Non-zero
  ///   `droppedHistoryEvents` or `droppedVariables` due to bounded retention.
  static List<LevitDiagnosticFinding> analyze(
    LevitStateSnapshot snapshot, {
    List<Map<String, dynamic>> recentErrors = const [],
    int highListenerThreshold = defaultHighListenerThreshold,
  }) {
    final findings = <LevitDiagnosticFinding>[];

    final unowned =
        snapshot.variables.values
            .where(
              (v) =>
                  v.ownerId == null || v.ownerId!.isEmpty || v.ownerId == '?',
            )
            .toList();
    if (unowned.isNotEmpty) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'unowned_reactives',
          severity: LevitDiagnosticSeverity.warning,
          message:
              '${unowned.length} reactive variable(s) have no ownerId '
              '(potential leak if not manually closed or owned via own()/enableAutoLinking).',
          details: {
            'count': unowned.length,
            'sample':
                unowned
                    .take(10)
                    .map((v) => {'id': v.id, 'name': v.name})
                    .toList(),
          },
        ),
      );
    }

    final closingScopes =
        snapshot.scopes.values
            .where((s) => s.progress['isClosing'] == true)
            .toList();
    if (closingScopes.isNotEmpty) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'closing_scopes',
          severity: LevitDiagnosticSeverity.warning,
          message:
              '${closingScopes.length} scope(s) are currently in closing state '
              '(check for stuck async cleanup or unawaited disposal).',
          details: {
            'scopes':
                closingScopes
                    .map(
                      (s) => {
                        'id': s.id,
                        'name': s.name,
                        'pendingInitializations':
                            s.progress['pendingInitializations'] ?? 0,
                      },
                    )
                    .toList(),
          },
        ),
      );
    }

    final pendingInitScopes =
        snapshot.scopes.values
            .where(
              (s) => (s.progress['pendingInitializations'] as int? ?? 0) > 0,
            )
            .toList();
    if (pendingInitScopes.isNotEmpty) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'pending_initializations',
          severity: LevitDiagnosticSeverity.info,
          message:
              '${pendingInitScopes.length} scope(s) have in-flight async initializations.',
          details: {
            'scopes':
                pendingInitScopes
                    .map(
                      (s) => {
                        'id': s.id,
                        'name': s.name,
                        'pendingInitializations':
                            s.progress['pendingInitializations'],
                      },
                    )
                    .toList(),
          },
        ),
      );
    }

    final highListeners =
        snapshot.variables.values
            .where((v) => v.listenerCount >= highListenerThreshold)
            .toList();
    if (highListeners.isNotEmpty) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'high_listener_count',
          severity: LevitDiagnosticSeverity.warning,
          message:
              '${highListeners.length} reactive variable(s) have '
              '>= $highListenerThreshold active listeners.',
          details: {
            'variables':
                highListeners
                    .take(10)
                    .map(
                      (v) => {
                        'id': v.id,
                        'name': v.name,
                        'ownerId': v.ownerId,
                        'listenerCount': v.listenerCount,
                      },
                    )
                    .toList(),
          },
        ),
      );
    }

    if (recentErrors.isNotEmpty) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'recent_errors',
          severity: LevitDiagnosticSeverity.error,
          message:
              '${recentErrors.length} runtime error event(s) captured in this session.',
          details: {'recent': recentErrors.take(10).toList()},
        ),
      );
    }

    if (snapshot.droppedHistoryEvents > 0 || snapshot.droppedVariables > 0) {
      findings.add(
        LevitDiagnosticFinding(
          code: 'dropped_telemetry',
          severity: LevitDiagnosticSeverity.info,
          message:
              'Bounded retention dropped ${snapshot.droppedHistoryEvents} history event(s) '
              'and ${snapshot.droppedVariables} variable(s).',
          details: {
            'droppedHistoryEvents': snapshot.droppedHistoryEvents,
            'droppedVariables': snapshot.droppedVariables,
          },
        ),
      );
    }

    return findings;
  }
}
