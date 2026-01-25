import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'event_model.dart';

/// Represents a single connected application session.
/// Represents a single connected application session.
class AppSession {
  final String sessionId;
  final String? appId;
  final DateTime connectedAt;
  final isConnected = true.lx;

  /// The shadow state of this session.
  final StateSnapshot state = StateSnapshot();

  /// The history of all events received in this session.
  final List<EventModel> eventLog = [];

  AppSession({required this.sessionId, this.appId})
    : connectedAt = DateTime.now();

  /// Processes an incoming event for this session.
  void handleEvent(MonitorEvent event, String rawJson) {
    // 1. Log the event
    final model = EventModel(
      event: event,
      receivedAt: DateTime.now(),
      rawJson: rawJson,
    );
    eventLog.add(model);

    // 2. Update shadow state
    state.applyEvent(event);
  }
}
