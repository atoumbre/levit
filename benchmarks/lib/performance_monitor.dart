import 'dart:async';
import 'dart:convert';

import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

/// Identical JSON serialization sink for both sides of a release comparison.
/// It counts bytes without retaining payloads or measuring external IO.
class PerformanceSink extends LevitTransport {
  int events = 0;
  int bytes = 0;

  @override
  void send(LevitMonitorEvent event) {
    bytes += utf8.encode(jsonEncode(event.toJson())).length;
    events++;
  }
}

/// The baseline adapter uses the old monitor's fixed 10,000-event history.
/// Keep the current history size equal and bound bursts above the largest
/// workload. Samples are invalid if delivery drops events.
class PerformanceMonitor {
  final sink = PerformanceSink();
  late final middleware = LevitMonitorMiddleware(
    transport: sink,
    historyCapacity: 10000,
    maxPendingEvents: 65536,
  );

  void enable() => middleware.enable();
  Future<void> flush() => middleware.flush();
  int get dropped => middleware.droppedEvents;
  bool get isAttached =>
      Levit.containsStateMiddleware(middleware) ||
      LevitScope.containsMiddleware(middleware);

  Future<void> close() async {
    // Legacy close() releases streams/transport but does not unregister hooks.
    // Keep explicit detachment identical on both sides of the comparison.
    middleware.disable();
    await middleware.close();
    if (isAttached) throw StateError('Monitor middleware survived teardown.');
  }
}
