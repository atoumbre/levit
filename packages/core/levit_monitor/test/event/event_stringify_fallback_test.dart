import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  test('LevitMonitorEvent stringify fallback', () {
    final unprintable = Unprintable();
    final event = LevitReactiveErrorEvent(sessionId: 's', error: unprintable);
    expect(event.toJson()['error'], contains('<unprintable>'));
  });
}

class Unprintable {
  @override
  String toString() => throw Exception('Cannot stringify');
}
