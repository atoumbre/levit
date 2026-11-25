import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  group('LevitConsoleTransport formats listener events', () {
    test('LevitConsoleTransport formats listener events', () {
      final transport = LevitConsoleTransport();
      final reactive = LxVar(0, name: 'test_var');

      final addEvent = LevitReactiveListenerAddedEvent(
        sessionId: 's1',
        reactive: reactive,
        context: const LxListenerContext(type: 'Test', id: 1, data: {'a': 1}),
      );

      final removeEvent = LevitReactiveListenerRemovedEvent(
        sessionId: 's1',
        reactive: reactive,
        context: const LxListenerContext(type: 'Test', id: 2, data: {'b': 2}),
      );

      transport.send(addEvent);
      transport.send(removeEvent);
    });

    test('LevitConsoleTransport log levels for listener events', () {
      final transport = LevitConsoleTransport();
      final reactive = LxVar(0);

      transport.send(
        LevitReactiveListenerAddedEvent(sessionId: 's', reactive: reactive),
      );
      transport.send(
        LevitReactiveListenerRemovedEvent(sessionId: 's', reactive: reactive),
      );
    });
  });
}
