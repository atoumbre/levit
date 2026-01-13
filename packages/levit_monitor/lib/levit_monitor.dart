library levit_monitor;

import 'package:levit_dart/levit_dart.dart';

import 'src/core/event.dart';
import 'src/core/transport.dart';
import 'src/middlewares/state.dart';
import 'src/transports/console_transport.dart';

export 'src/core/event.dart';
export 'src/core/transport.dart';
export 'src/middlewares/state.dart';
export 'src/transports/console_transport.dart';
export 'src/transports/file_transport.dart';
export 'src/transports/websocket_transport.dart';

/// A unified monitoring entry point for Levit applications.
class LevitMonitor {
  static MonitorMiddleware? _middleware;

  /// The current event filter function.
  ///
  /// If set, only events for which this function returns `true` will be
  /// processed by the monitor. If `null`, all events are processed.
  static bool Function(MonitorEvent event)? _filter;

  /// Gets the currently active filter, or `null` if no filter is set.
  static bool Function(MonitorEvent event)? get filter => _filter;

  /// Sets a filter function to customize which events are monitored.
  ///
  /// The [filter] function receives each [MonitorEvent] and should return
  /// `true` to allow the event, or `false` to suppress it.
  ///
  /// Pass `null` to remove the filter and allow all events.
  ///
  /// ```dart
  /// // Only monitor state change events
  /// LevitMonitor.setFilter((event) => event is StateChangeEvent);
  ///
  /// // Only monitor DI events
  /// LevitMonitor.setFilter((event) => event is DIEvent);
  ///
  /// // Exclude batch events
  /// LevitMonitor.setFilter((event) => event is! BatchEvent);
  ///
  /// // Clear filter
  /// LevitMonitor.setFilter(null);
  /// ```
  static void setFilter(bool Function(MonitorEvent event)? filter) {
    _filter = filter;
  }

  /// Checks if an event passes the current filter.
  ///
  /// Returns `true` if the event should be processed, `false` otherwise.
  static bool shouldProcess(MonitorEvent event) {
    return _filter == null || _filter!(event);
  }

  /// Attaches the monitor to the running Levit application.
  ///
  /// * [transport]: The transport to use for sending events. Defaults to [ConsoleTransport].
  static void attach({LevitTransport? transport}) {
    detach(); // Ensure clean state

    Levit.enableAutoLinking();

    final t = transport ?? const ConsoleTransport();

    _middleware = MonitorMiddleware(transport: t);
    _middleware?.enable();
  }

  static void detach() {
    _middleware?.disable();
    _middleware = null;
  }
}
