import 'package:levit_monitor/levit_monitor.dart';

/// A wrapper around [MonitorEvent] that adds metadata local to the DevTools
/// server, such as the exact time of receipt.
class EventModel {
  final MonitorEvent event;
  final DateTime receivedAt;
  final String rawJson;

  EventModel({
    required this.event,
    required this.receivedAt,
    required this.rawJson,
  });
}
