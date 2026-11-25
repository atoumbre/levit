import 'dart:async';

import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _SlowCloseTransport extends LevitTransport {
  final Completer<void> closeStarted = Completer<void>();
  final Completer<void> allowClose = Completer<void>();
  final List<MonitorEvent> sent = [];

  @override
  FutureOr<void> send(MonitorEvent event) {
    sent.add(event);
  }

  @override
  Future<void> close() async {
    if (!closeStarted.isCompleted) closeStarted.complete();
    await allowClose.future;
  }
}

class _MemoryTransport extends LevitTransport {
  final List<MonitorEvent> sent = [];

  @override
  FutureOr<void> send(MonitorEvent event) {
    sent.add(event);
  }
}

void main() {
  test('flush completes cleanly when overlapping with updateTransport', () async {
    final oldTransport = _SlowCloseTransport();
    final newTransport = _MemoryTransport();
    final middleware = LevitMonitorMiddleware(transport: oldTransport);
    middleware.enable();

    final counter = 0.lx;
    counter.value = 1;

    final updating = middleware.updateTransport(transport: newTransport);
    await oldTransport.closeStarted.future;

    // Emit an event while transport replacement has paused pumping, then flush.
    counter.value = 2;
    final flushing = middleware.flush();

    // Yield to ensure flush does not starve the event loop before releasing close.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    oldTransport.allowClose.complete();

    await Future.wait([updating, flushing]).timeout(const Duration(seconds: 2));
    expect(newTransport.sent, isNotEmpty);

    await middleware.close();
    await counter.close();
  });
}
