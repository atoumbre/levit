import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../client/devtools_client.dart';

/// Filter pills available in the Reactives tab.
enum ReactiveFilterMode { all, sensitive, unowned, computed, highListeners }

/// Owns the client-side [LevitStateSnapshot], live stream buffering, filters,
/// and deterministic anomaly diagnostics for the DevTools extension UI.
class LevitInspectorController extends LevitController {
  /// Maximum history events retained in the DevTools UI buffer.
  static const int maxTimelineEvents = 500;

  /// Maximum error summaries retained in the DevTools UI buffer.
  static const int maxRecentErrors = 50;

  final LevitDevToolsClient _client;
  final bool _ownsClient;

  LevitStateSnapshot _snapshot = LevitStateSnapshot(
    maxEvents: maxTimelineEvents,
    maxVariables: 4096,
  );
  final ListQueue<Map<String, dynamic>> _recentErrors = ListQueue();
  final ListQueue<LevitEventEnvelope> _pausedBuffer = ListQueue();

  /// Whether the target isolate has `LevitDevTools` / `LevitMonitor` attached.
  final attached = false.lx;

  /// Whether a snapshot refresh is currently in progress.
  final loading = false.lx;

  /// Whether live event ingestion is currently paused.
  final paused = false.lx;

  /// Number of events queued while paused.
  final pausedCount = 0.lx;

  /// Last connection or refresh error, if any.
  final errorMessage = LxVar<String?>(null);

  /// Monotonic counter incremented whenever snapshot data changes.
  final revision = 0.lx;

  /// Total dropped events reported by the target isolate.
  final droppedEvents = 0.lx;

  /// Active tab index (`0=Scopes`, `1=Reactives`, `2=Tasks`, `3=Timeline`, `4=Diagnostics`).
  final activeTabIndex = 0.lx;

  /// Currently selected scope ID in the Scopes tab.
  final selectedScopeId = LxVar<int?>(null);

  /// Currently selected reactive ID in the Reactives tab.
  final selectedReactiveId = LxVar<int?>(null);

  /// Currently selected timeline event sequence number.
  final selectedEventSeq = LxVar<int?>(null);

  /// Search query for the Reactives tab.
  final reactiveSearch = ''.lx;

  /// Quick filter mode for the Reactives tab.
  final reactiveFilter = LxVar<ReactiveFilterMode>(ReactiveFilterMode.all);

  /// Search query for the Timeline tab.
  final timelineSearch = ''.lx;

  /// Optional category filter (`state`, `di`, `log`, `custom`, `error`) for Timeline.
  final timelineCategory = LxVar<String?>(null);

  /// Configurable high-listener warning threshold for Diagnostics.
  final highListenerThreshold =
      LevitSnapshotDiagnostics.defaultHighListenerThreshold.lx;

  LevitInspectorController(this._client, {bool ownsClient = true})
    : _ownsClient = ownsClient;

  /// Current redacted shadow state reconstructed from snapshot + live events.
  LevitStateSnapshot get snapshot => _snapshot;

  /// Unmodifiable view of recent error summaries.
  List<Map<String, dynamic>> get recentErrors =>
      List.unmodifiable(_recentErrors);

  /// Live deterministic diagnostic findings computed from [snapshot].
  List<LevitDiagnosticFinding> get findings => LevitSnapshotDiagnostics.analyze(
    _snapshot,
    recentErrors: recentErrors,
    highListenerThreshold: highListenerThreshold.value,
  );

  @override
  void onInit() {
    super.onInit();
    own(_client.events.listen(_handleIncomingEvent));
    own(
      _client.connectionChanges.listen((connected) {
        if (connected) {
          unawaited(refresh());
        } else {
          attached.value = false;
        }
      }),
    );
    unawaited(refresh());
  }

  /// Hydrates the client snapshot and history from the connected target isolate.
  Future<void> refresh() async {
    if (isClosed) return;
    loading.value = true;
    errorMessage.value = null;
    try {
      final result = await _client.fetchSnapshot();
      if (isClosed) return;

      attached.value = result.attached;
      droppedEvents.value = result.droppedEvents;

      final nextSnapshot = LevitStateSnapshot(
        maxEvents: maxTimelineEvents,
        maxVariables: 4096,
      );
      if (result.attached && result.snapshot != null) {
        nextSnapshot.applyEnvelope(
          LevitEventEnvelope({
            'sessionId': 'devtools',
            'seq': 0,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'type': 'snapshot',
            'category': 'system',
            'state': result.snapshot!,
          }),
        );
        final history = await _client.fetchHistory(limit: maxTimelineEvents);
        if (isClosed) return;
        for (final envelope in history) {
          nextSnapshot.applyEnvelope(envelope);
        }
      }

      _snapshot = nextSnapshot;
      _recentErrors
        ..clear()
        ..addAll(result.recentErrors.take(maxRecentErrors));
      _pausedBuffer.clear();
      pausedCount.value = 0;

      if (selectedScopeId.value == null && _snapshot.scopes.isNotEmpty) {
        selectedScopeId.value = _snapshot.scopes.keys.first;
      } else if (selectedScopeId.value != null &&
          !_snapshot.scopes.containsKey(selectedScopeId.value)) {
        selectedScopeId.value =
            _snapshot.scopes.isEmpty ? null : _snapshot.scopes.keys.first;
      }

      revision.value++;
    } catch (error) {
      if (!isClosed) {
        errorMessage.value = '$error';
      }
    } finally {
      if (!isClosed) {
        loading.value = false;
      }
    }
  }

  void _handleIncomingEvent(LevitEventEnvelope envelope) {
    if (isClosed) return;
    if (!attached.value) {
      attached.value = true;
    }
    if (paused.value) {
      if (_pausedBuffer.length == maxTimelineEvents) {
        _pausedBuffer.removeFirst();
      }
      _pausedBuffer.add(envelope);
      pausedCount.value = _pausedBuffer.length;
      return;
    }
    _applyEnvelope(envelope);
    revision.value++;
  }

  void _applyEnvelope(LevitEventEnvelope envelope) {
    _snapshot.applyEnvelope(envelope);
    final errorSummary = LevitSnapshotDiagnostics.extractErrorSummary(envelope);
    if (errorSummary != null) {
      if (_recentErrors.length == maxRecentErrors) {
        _recentErrors.removeFirst();
      }
      _recentErrors.add(errorSummary);
    }
  }

  /// Toggles live event streaming; resuming flushes buffered events in order.
  void togglePause() {
    if (paused.value) {
      paused.value = false;
      if (_pausedBuffer.isNotEmpty) {
        for (final envelope in _pausedBuffer) {
          _applyEnvelope(envelope);
        }
        _pausedBuffer.clear();
        pausedCount.value = 0;
        revision.value++;
      }
    } else {
      paused.value = true;
    }
  }

  /// Clears locally retained timeline history without modifying the target app.
  void clearLocalTimeline() {
    final raw = _snapshot.toJson();
    final next = LevitStateSnapshot(
      maxEvents: maxTimelineEvents,
      maxVariables: 4096,
    );
    next.applyEnvelope(
      LevitEventEnvelope({
        'sessionId': 'devtools',
        'seq': 0,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'type': 'snapshot',
        'category': 'system',
        'state': raw,
      }),
    );
    _snapshot = next;
    selectedEventSeq.value = null;
    revision.value++;
  }

  /// Jumps to a specific scope in the Scopes tab.
  void focusScope(int scopeId) {
    selectedScopeId.value = scopeId;
    activeTabIndex.value = 0;
  }

  /// Jumps to a specific reactive in the Reactives tab.
  void focusReactive(int reactiveId) {
    selectedReactiveId.value = reactiveId;
    activeTabIndex.value = 1;
  }

  /// Filtered reactive variables matching [reactiveSearch] and [reactiveFilter].
  List<LevitReactiveModel> get filteredReactives {
    final query = reactiveSearch.value.trim().toLowerCase();
    final filter = reactiveFilter.value;
    final threshold = highListenerThreshold.value;

    final list =
        _snapshot.variables.values.where((v) {
            switch (filter) {
              case ReactiveFilterMode.all:
                break;
              case ReactiveFilterMode.sensitive:
                if (!v.isSensitive) return false;
              case ReactiveFilterMode.unowned:
                if (v.ownerId != null &&
                    v.ownerId!.isNotEmpty &&
                    v.ownerId != '?') {
                  return false;
                }
              case ReactiveFilterMode.computed:
                if (v.dependencies.isEmpty) return false;
              case ReactiveFilterMode.highListeners:
                if (v.listenerCount < threshold) return false;
            }
            if (query.isEmpty) return true;
            return v.name.toLowerCase().contains(query) ||
                (v.ownerId?.toLowerCase().contains(query) ?? false) ||
                (v.valueType?.toLowerCase().contains(query) ?? false) ||
                '${v.id}'.contains(query);
          }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Filtered timeline events in reverse-chronological order (newest first).
  List<LevitEventEnvelope> get filteredTimeline {
    final query = timelineSearch.value.trim().toLowerCase();
    final category = timelineCategory.value;
    final matched = <LevitEventEnvelope>[];
    for (final envelope in _snapshot.events.reversed) {
      if (category != null && envelope.category != category) continue;
      if (query.isNotEmpty) {
        final data = envelope.data;
        final haystack =
            '${envelope.type} ${envelope.category} ${data['name'] ?? ''} '
                    '${data['key'] ?? ''} ${data['ownerId'] ?? ''} '
                    '${data['scopeName'] ?? ''} ${data['error'] ?? ''}'
                .toLowerCase();
        if (!haystack.contains(query)) continue;
      }
      matched.add(envelope);
    }
    return matched;
  }

  /// Returns downstream reactive models that list [reactiveId] in their
  /// upstream `dependencies`.
  List<LevitReactiveModel> downstreamDependentsOf(int reactiveId) {
    return _snapshot.variables.values
        .where((v) => v.dependencies.contains(reactiveId))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Exports a pretty-printed, redacted JSON snapshot for sharing/bug reports.
  String exportRedactedJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'snapshot': _snapshot.toJson(),
      'recentErrors': recentErrors,
      'findings': findings.map((f) => f.toJson()).toList(),
      'droppedEvents': droppedEvents.value,
    });
  }

  @override
  Future<void> onClose() async {
    if (_ownsClient) {
      await _client.dispose();
    }
    await super.onClose();
  }
}
