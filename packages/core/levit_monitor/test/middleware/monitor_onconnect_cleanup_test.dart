import 'dart:async';

import 'package:test/test.dart';
import 'package:levit_monitor/levit_monitor.dart';

void main() {
  test('onConnect does not emit after disable', () async {
    final transport = _TestTransport();
    final middleware = LevitMonitorMiddleware(transport: transport);
    middleware.enable();

    transport.connect();
    await Future<void>.delayed(Duration.zero);
    expect(transport.snapshotCount, 1);

    transport.clear();
    middleware.disable();

    transport.connect();
    await Future<void>.delayed(Duration.zero);
    expect(transport.snapshotCount, 0);

    await middleware.close();
  });

  test('updateTransport swaps onConnect subscription', () async {
    final transport1 = _TestTransport();
    final middleware = LevitMonitorMiddleware(transport: transport1);
    middleware.enable();

    final transport2 = _TestTransport();
    await middleware.updateTransport(transport: transport2);

    transport2.connect();
    await Future<void>.delayed(Duration.zero);
    expect(transport2.snapshotCount, 1);

    await middleware.close();
  });
}

class _TestTransport implements LevitTransport {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  final List<MonitorEvent> _events = [];

  @override
  Stream<void> get onConnect => _controller.stream;

  @override
  void send(MonitorEvent event) {
    _events.add(event);
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }

  void connect() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  int get snapshotCount => _events.whereType<SnapshotEvent>().length;

  void clear() => _events.clear();
}
