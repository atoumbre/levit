import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('MonitorEvent stringify fallback', () {
    final unprintable = Unprintable();
    final event = ReactiveErrorEvent(sessionId: 's', error: unprintable);
    expect(event.toJson()['error'], contains('<unprintable>'));
  });
}

class Unprintable {
  @override
  String toString() => throw Exception('Cannot stringify');
}
