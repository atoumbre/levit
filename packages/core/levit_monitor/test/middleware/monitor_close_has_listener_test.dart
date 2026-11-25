import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  test('close drains the admitted send before closing its transport', () async {
    final transport = _Blocked();
    final middleware = LevitMonitorMiddleware(transport: transport)..enable();
    final value = 0.lx;
    value.value = 1;
    final closed = middleware.close();
    await Future<void>.delayed(Duration.zero);
    expect(transport.closed, isFalse);
    transport.release.complete();
    await closed;
    expect(transport.closed, isTrue);
    await value.close();
  });
}

class _Blocked extends LevitTransport {
  final release = Completer<void>();
  bool closed = false;
  @override
  Future<void> send(LevitMonitorEvent event) => release.future;
  @override
  Future<void> close() async {
    closed = true;
  }
}
