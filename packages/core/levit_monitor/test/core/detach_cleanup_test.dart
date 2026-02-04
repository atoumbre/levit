import 'dart:async';

import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class _CloseTrackingTransport implements LevitTransport {
  final Completer<void> closeCompleter = Completer<void>();
  bool closed = false;

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(MonitorEvent event) {}

  @override
  Future<void> close() async {
    closed = true;
    if (!closeCompleter.isCompleted) {
      closeCompleter.complete();
    }
  }
}

void main() {
  test('LevitMonitor.detach closes active transport', () async {
    final transport = _CloseTrackingTransport();

    LevitMonitor.attach(transport: transport);
    LevitMonitor.detach();

    await transport.closeCompleter.future.timeout(Duration(seconds: 1));
    expect(transport.closed, isTrue);
  });

  test('LevitMonitor.attach closes previous transport', () async {
    final first = _CloseTrackingTransport();
    final second = _CloseTrackingTransport();

    LevitMonitor.attach(transport: first);
    LevitMonitor.attach(transport: second);

    await first.closeCompleter.future.timeout(Duration(seconds: 1));
    expect(first.closed, isTrue);

    LevitMonitor.detach();
    await second.closeCompleter.future.timeout(Duration(seconds: 1));
    expect(second.closed, isTrue);
  });
}
