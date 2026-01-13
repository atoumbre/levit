import 'event.dart';

/// Interface for transporting [MonitorEvent]s to external systems.
abstract class LevitTransport {
  /// Sends a monitor event to the transport destination.
  void send(MonitorEvent event);

  /// Closes the transport connection. Override for cleanup.
  void close() {}
}
