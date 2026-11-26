import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:levit_monitor/spi.dart';
import 'package:vm_service/vm_service.dart' as vm;

import 'devtools_client.dart';

/// Live [LevitDevToolsClient] backed by `devtools_extensions`'s [serviceManager].
class VmServiceLevitClient implements LevitDevToolsClient {
  final StreamController<LevitEventEnvelope> _eventsController =
      StreamController<LevitEventEnvelope>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  StreamSubscription<vm.Event>? _extensionSub;
  bool _disposed = false;

  VmServiceLevitClient() {
    serviceManager.connectedState.addListener(_onConnectionChanged);
    serviceManager.isolateManager.selectedIsolate.addListener(
      _onConnectionChanged,
    );
    unawaited(_bindEventStream());
  }

  @override
  Stream<LevitEventEnvelope> get events => _eventsController.stream;

  @override
  Stream<bool> get connectionChanges => _connectionController.stream;

  void _onConnectionChanged() {
    if (_disposed) return;
    final connected = serviceManager.connectedState.value.connected;
    _connectionController.add(connected);
    if (connected) {
      unawaited(_bindEventStream());
    }
  }

  Future<void> _bindEventStream() async {
    if (_disposed) return;
    final service = serviceManager.service;
    if (service == null) return;

    await _extensionSub?.cancel();
    _extensionSub = null;

    try {
      await service.streamListen(vm.EventStreams.kExtension);
    } catch (_) {
      // Stream may already be subscribed by DevTools host.
    }

    if (_disposed) return;
    _extensionSub = service.onExtensionEvent.listen((vm.Event event) {
      if (_disposed || event.extensionKind != LevitDevToolsProtocol.eventKind) {
        return;
      }
      final raw = event.extensionData?.data;
      if (raw == null) return;
      try {
        final envelope = LevitEventEnvelope(Map<String, dynamic>.from(raw));
        if (!_eventsController.isClosed) {
          _eventsController.add(envelope);
        }
      } catch (_) {
        // Ignore malformed frames without disrupting live inspection.
      }
    });
  }

  String? _selectedIsolateId() =>
      serviceManager.isolateManager.selectedIsolate.value?.id;

  @override
  Future<LevitRemoteSnapshotResult> fetchSnapshot() async {
    final service = serviceManager.service;
    final isolateId = _selectedIsolateId();
    if (service == null || isolateId == null) {
      return const LevitRemoteSnapshotResult.unattached();
    }

    try {
      final response = await service.callServiceExtension(
        LevitDevToolsProtocol.getSnapshotExtension,
        isolateId: isolateId,
      );
      final json = response.json;
      if (json == null || json['attached'] != true) {
        return const LevitRemoteSnapshotResult.unattached();
      }
      final rawSnap = json['snapshot'];
      final rawErrors = json['recentErrors'];
      return LevitRemoteSnapshotResult(
        attached: true,
        snapshot: rawSnap is Map ? Map<String, dynamic>.from(rawSnap) : null,
        recentErrors:
            rawErrors is List
                ? rawErrors
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : const [],
        droppedEvents: (json['droppedEvents'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const LevitRemoteSnapshotResult.unattached();
    }
  }

  @override
  Future<List<LevitEventEnvelope>> fetchHistory({int limit = 500}) async {
    final service = serviceManager.service;
    final isolateId = _selectedIsolateId();
    if (service == null || isolateId == null) return const [];

    try {
      final response = await service.callServiceExtension(
        LevitDevToolsProtocol.getHistoryExtension,
        isolateId: isolateId,
        args: {'limit': '$limit'},
      );
      final json = response.json;
      if (json == null || json['attached'] != true) return const [];
      final rawEvents = json['events'];
      if (rawEvents is! List) return const [];
      return [
        for (final item in rawEvents)
          if (item is Map) LevitEventEnvelope(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    serviceManager.connectedState.removeListener(_onConnectionChanged);
    serviceManager.isolateManager.selectedIsolate.removeListener(
      _onConnectionChanged,
    );
    await _extensionSub?.cancel();
    _extensionSub = null;
    await _eventsController.close();
    await _connectionController.close();
  }
}
