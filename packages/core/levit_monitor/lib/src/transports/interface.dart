part of '../monitor_library.dart';

/// Interface for dispatching diagnostic events to external sinks.
///
/// [LevitTransport] defines how [LevitMonitorEvent]s are delivered to developers,
/// logs, or visualization tools. Implementations can range from simple
/// console printing to complex network-based telemetry.
///
/// {@category Middleware & Monitoring}
abstract class LevitTransport {
  /// Dispatches the [event] to the transport destination.
  ///
  /// This method is called by the monitor whenever an event passes through
  /// the active filtering pipeline.
  FutureOr<void> send(LevitMonitorEvent event);

  /// Completes when all admitted sends have reached the destination buffer.
  Future<void> flush() async {}

  /// Events dropped by this transport since creation.
  int get droppedEvents => 0;

  /// Releases resources and closes any active connections.
  ///
  /// This method should be called when the transport is no longer needed,
  /// typically during [LevitMonitor.detach].
  Future<void> close() async {}

  /// Stream that emits when a connection is established or re-established.
  Stream<void> get onConnect => const Stream<void>.empty();
}
