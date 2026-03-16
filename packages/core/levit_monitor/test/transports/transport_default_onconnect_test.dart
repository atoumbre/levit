import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('LevitTransport default onConnect', () {
    final t = StubTransport();
    expect(t.onConnect, isNotNull);
  });
}

class StubTransport extends LevitTransport {
  @override
  void send(MonitorEvent event) {}
}
