import 'package:levit_monitor/spi.dart';

import 'session_store.dart';

export 'package:levit_monitor/spi.dart'
    show LevitDiagnosticFinding, LevitDiagnosticSeverity;

/// Deterministic runtime anomaly analyzer operating on [LevitMcpSession].
///
/// Delegates to the shared [LevitSnapshotDiagnostics] analyzer in
/// `package:levit_monitor/spi.dart` so MCP agents and DevTools extensions
/// report identical finding codes and thresholds.
///
/// {@category Session & Diagnostics}
abstract final class LevitRuntimeDiagnostics {
  /// Default threshold above which a reactive's listener count triggers a warning.
  static const int defaultHighListenerThreshold =
      LevitSnapshotDiagnostics.defaultHighListenerThreshold;

  /// Runs all built-in deterministic diagnostic checks against [session].
  static List<LevitDiagnosticFinding> analyze(
    LevitMcpSession session, {
    int highListenerThreshold = defaultHighListenerThreshold,
  }) {
    return LevitSnapshotDiagnostics.analyze(
      session.snapshot,
      recentErrors: session.recentErrors,
      highListenerThreshold: highListenerThreshold,
    );
  }
}
