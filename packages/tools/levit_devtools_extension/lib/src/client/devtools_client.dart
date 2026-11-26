import 'package:levit_monitor/spi.dart';

/// Response from `ext.levit.getSnapshot`.
final class LevitRemoteSnapshotResult {
  /// Whether `LevitDevTools` / `LevitMonitor` is attached in the target isolate.
  final bool attached;

  /// Raw redacted snapshot map matching [LevitStateSnapshot.toJson], if attached.
  final Map<String, dynamic>? snapshot;

  /// Recent redacted error summaries captured by the target transport.
  final List<Map<String, dynamic>> recentErrors;

  /// Total dropped events reported by the target runtime.
  final int droppedEvents;

  const LevitRemoteSnapshotResult({
    required this.attached,
    this.snapshot,
    this.recentErrors = const [],
    this.droppedEvents = 0,
  });

  /// Represents an isolate where `levit_devtools` is not attached.
  const LevitRemoteSnapshotResult.unattached()
    : attached = false,
      snapshot = null,
      recentErrors = const [],
      droppedEvents = 0;
}

/// Read-only transport abstraction between the DevTools UI and the target app.
abstract interface class LevitDevToolsClient {
  /// Fetches the current redacted runtime snapshot and recent error summaries.
  Future<LevitRemoteSnapshotResult> fetchSnapshot();

  /// Fetches retained history envelopes from the target isolate.
  Future<List<LevitEventEnvelope>> fetchHistory({int limit = 500});

  /// Live stream of redacted [LevitEventEnvelope]s from `ext.levit.event`.
  Stream<LevitEventEnvelope> get events;

  /// Emits `true` when the target VM Service connection/isolate becomes ready.
  Stream<bool> get connectionChanges;

  /// Releases subscriptions owned by this client.
  Future<void> dispose();
}
