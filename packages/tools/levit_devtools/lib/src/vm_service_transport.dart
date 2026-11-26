import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/spi.dart';

/// Signature matching `dart:developer`'s `postEvent` for dependency injection
/// in tests.
///
/// {@category VM Service Protocol}
typedef LevitVmServicePostEvent =
    void Function(String eventKind, Map<Object?, Object?> eventData);

/// Signature matching `dart:developer`'s `registerExtension` for dependency
/// injection in tests.
///
/// {@category VM Service Protocol}
typedef LevitVmServiceRegisterExtension =
    void Function(String method, developer.ServiceExtensionHandler handler);

/// Stable Dart VM Service extension names and event constants shared between
/// `levit_devtools` and the Flutter DevTools extension UI.
///
/// {@category VM Service Protocol}
abstract final class LevitDevToolsProtocol {
  /// Wire schema version reported by `ext.levit.*` service extensions.
  static const int protocolVersion = 1;

  /// `dart:developer.postEvent` event kind carrying redacted
  /// [LevitEventEnvelope] JSON payloads.
  static const String eventKind = 'ext.levit.event';

  /// VM Service extension returning the current redacted [LevitMonitor.snapshot]
  /// and recent error summaries.
  static const String getSnapshotExtension = 'ext.levit.getSnapshot';

  /// VM Service extension returning filtered [LevitMonitor.history] envelopes.
  static const String getHistoryExtension = 'ext.levit.getHistory';

  /// VM Service extension returning deterministic [LevitSnapshotDiagnostics]
  /// findings for the active runtime snapshot.
  static const String getDiagnosticsExtension = 'ext.levit.getDiagnostics';
}

/// Read-only [LevitTransport] that streams redacted [LevitEventEnvelope]
/// payloads over `dart:developer.postEvent` and serves snapshot, history, and
/// diagnostics queries via `dart:developer.registerExtension`.
///
/// Works on Dart VM, Flutter mobile/desktop, and Flutter Web without opening
/// network sockets or managing local auth tokens.
///
/// {@category DevTools Integration}
class LevitVmServiceTransport extends LevitTransport {
  static final Set<String> _registeredExtensions = <String>{};
  static LevitVmServiceTransport? _activeTransport;

  final LevitVmServicePostEvent _postEvent;
  final LevitVmServiceRegisterExtension _registerExtension;
  final Map<String, dynamic>? Function() _readSnapshot;
  final List<LevitEventEnvelope> Function() _readHistory;
  final int Function() _readDroppedEvents;
  final ListQueue<Map<String, dynamic>> _recentErrors = ListQueue();

  /// Maximum error summaries retained for `ext.levit.getSnapshot` and
  /// `ext.levit.getDiagnostics`.
  final int maxRecentErrors;

  bool _closed = false;
  int _droppedEvents = 0;

  /// Creates a VM Service transport and registers the read-only `ext.levit.*`
  /// service extensions (idempotently per isolate).
  ///
  /// Supply custom [postEvent], [registerExtension], [readSnapshot],
  /// [readHistory], or [readDroppedEvents] hooks only for testing.
  LevitVmServiceTransport({
    this.maxRecentErrors = 50,
    LevitVmServicePostEvent? postEvent,
    LevitVmServiceRegisterExtension? registerExtension,
    Map<String, dynamic>? Function()? readSnapshot,
    List<LevitEventEnvelope> Function()? readHistory,
    int Function()? readDroppedEvents,
  }) : _postEvent = postEvent ?? developer.postEvent,
       _registerExtension = registerExtension ?? developer.registerExtension,
       _readSnapshot = readSnapshot ?? (() => LevitMonitor.snapshot),
       _readHistory = readHistory ?? (() => LevitMonitor.history),
       _readDroppedEvents =
           readDroppedEvents ?? (() => LevitMonitor.droppedEvents) {
    if (maxRecentErrors < 1) {
      throw RangeError.value(maxRecentErrors, 'maxRecentErrors');
    }
    _activeTransport = this;
    _ensureExtensionsRegistered(customRegistrar: registerExtension != null);
  }

  /// Unmodifiable view of recent redacted error summaries captured by this
  /// transport.
  List<Map<String, dynamic>> get recentErrors =>
      List.unmodifiable(_recentErrors);

  @override
  int get droppedEvents => _droppedEvents;

  @override
  void send(LevitMonitorEvent event) {
    if (_closed) {
      _droppedEvents++;
      return;
    }
    final envelope = event.freeze().envelope;
    final errorSummary = LevitSnapshotDiagnostics.extractErrorSummary(envelope);
    if (errorSummary != null) {
      if (_recentErrors.length == maxRecentErrors) {
        _recentErrors.removeFirst();
      }
      _recentErrors.add(errorSummary);
    }
    try {
      _postEvent(LevitDevToolsProtocol.eventKind, envelope.toJson());
    } catch (_) {
      _droppedEvents++;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    if (identical(_activeTransport, this)) {
      _activeTransport = null;
    }
  }

  void _ensureExtensionsRegistered({required bool customRegistrar}) {
    final handlers = <String, developer.ServiceExtensionHandler>{
      LevitDevToolsProtocol.getSnapshotExtension: _handleGetSnapshot,
      LevitDevToolsProtocol.getHistoryExtension: _handleGetHistory,
      LevitDevToolsProtocol.getDiagnosticsExtension: _handleGetDiagnostics,
    };
    for (final entry in handlers.entries) {
      if (customRegistrar || _registeredExtensions.add(entry.key)) {
        try {
          _registerExtension(entry.key, entry.value);
        } on ArgumentError {
          // Another instance in this isolate already registered the extension.
        }
      }
    }
  }

  static Future<developer.ServiceExtensionResponse> _handleGetSnapshot(
    String method,
    Map<String, String> parameters,
  ) async {
    final active = _activeTransport;
    if (active == null || active._closed) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'attached': false,
          'protocolVersion': LevitDevToolsProtocol.protocolVersion,
        }),
      );
    }
    final snapshot = active._readSnapshot();
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'attached': snapshot != null,
        'protocolVersion': LevitDevToolsProtocol.protocolVersion,
        'droppedEvents': active._readDroppedEvents(),
        'snapshot': snapshot,
        'recentErrors': active.recentErrors,
      }),
    );
  }

  static Future<developer.ServiceExtensionResponse> _handleGetHistory(
    String method,
    Map<String, String> parameters,
  ) async {
    final active = _activeTransport;
    if (active == null || active._closed) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'attached': false,
          'protocolVersion': LevitDevToolsProtocol.protocolVersion,
          'events': const <Object>[],
        }),
      );
    }

    final limit = (int.tryParse(parameters['limit'] ?? '') ?? 200).clamp(
      1,
      2000,
    );
    final category = parameters['category'];
    final type = parameters['type'];
    final sinceSeq = int.tryParse(parameters['sinceSeq'] ?? '');

    final allHistory = active._readHistory();
    final filtered = <Map<String, dynamic>>[];
    for (final envelope in allHistory) {
      if (sinceSeq != null && envelope.seq <= sinceSeq) continue;
      if (category != null &&
          category.isNotEmpty &&
          envelope.category != category) {
        continue;
      }
      if (type != null && type.isNotEmpty && envelope.type != type) continue;
      filtered.add(envelope.toJson());
    }

    final sliced =
        filtered.length > limit
            ? filtered.sublist(filtered.length - limit)
            : filtered;

    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'attached': true,
        'protocolVersion': LevitDevToolsProtocol.protocolVersion,
        'totalRetained': allHistory.length,
        'droppedEvents': active._readDroppedEvents(),
        'events': sliced,
      }),
    );
  }

  static Future<developer.ServiceExtensionResponse> _handleGetDiagnostics(
    String method,
    Map<String, String> parameters,
  ) async {
    final active = _activeTransport;
    if (active == null || active._closed) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'attached': false,
          'protocolVersion': LevitDevToolsProtocol.protocolVersion,
          'findings': const <Object>[],
        }),
      );
    }

    final rawSnapshot = active._readSnapshot();
    if (rawSnapshot == null) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'attached': false,
          'protocolVersion': LevitDevToolsProtocol.protocolVersion,
          'findings': const <Object>[],
        }),
      );
    }

    final threshold = (int.tryParse(
              parameters['highListenerThreshold'] ?? '',
            ) ??
            LevitSnapshotDiagnostics.defaultHighListenerThreshold)
        .clamp(1, 100000);

    final rebuilt = LevitStateSnapshot();
    rebuilt.applyEnvelope(
      LevitEventEnvelope({
        'sessionId': 'devtools',
        'seq': 0,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'type': 'snapshot',
        'category': 'system',
        'state': rawSnapshot,
      }),
    );

    final findings = LevitSnapshotDiagnostics.analyze(
      rebuilt,
      recentErrors: active.recentErrors,
      highListenerThreshold: threshold,
    );

    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'attached': true,
        'protocolVersion': LevitDevToolsProtocol.protocolVersion,
        'findings': findings.map((f) => f.toJson()).toList(),
      }),
    );
  }
}

/// High-level bootstrap facade for connecting a running Dart or Flutter
/// application to the Levit Flutter DevTools extension.
///
/// {@category DevTools Integration}
abstract final class LevitDevTools {
  /// Whether a [LevitVmServiceTransport] is currently active in this isolate.
  static bool get isAttached =>
      LevitVmServiceTransport._activeTransport != null &&
      !LevitVmServiceTransport._activeTransport!._closed;

  /// Attaches [LevitMonitor] with a [LevitVmServiceTransport] (plus optional
  /// [extraTransports]) so Flutter DevTools can inspect live runtime state.
  ///
  /// Automatically a no-op in release builds (`dart.vm.product == true`) unless
  /// [allowInRelease] is explicitly set to `true`.
  static Future<void> attach({
    int historyCapacity = 500,
    int maxPendingEvents = 1024,
    int maxRecentErrors = 50,
    bool includeStackTrace = false,
    bool enableWorkerStatistics = false,
    List<LevitTransport> extraTransports = const [],
    bool allowInRelease = false,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product') && !allowInRelease) {
      return;
    }
    final transport = LevitVmServiceTransport(maxRecentErrors: maxRecentErrors);
    await LevitMonitor.attach(
      transports: [transport, ...extraTransports],
      historyCapacity: historyCapacity,
      maxPendingEvents: maxPendingEvents,
      includeStackTrace: includeStackTrace,
      enableWorkerStatistics: enableWorkerStatistics,
    );
  }

  /// Detaches [LevitMonitor] and closes the active DevTools transport.
  static Future<void> detach() => LevitMonitor.detach();
}
