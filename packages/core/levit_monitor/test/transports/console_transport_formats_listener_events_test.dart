import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleTransport formats listener events', () {
    test('ConsoleTransport formats listener events', () {
      final transport = ConsoleTransport();
      final reactive = LxVar(0, name: 'test_var');

      final addEvent = ReactiveListenerAddedEvent(
        sessionId: 's1',
        reactive: reactive,
        context: const LxListenerContext(type: 'Test', id: 1, data: {'a': 1}),
      );

      final removeEvent = ReactiveListenerRemovedEvent(
        sessionId: 's1',
        reactive: reactive,
        context: const LxListenerContext(type: 'Test', id: 2, data: {'b': 2}),
      );

      transport.send(addEvent);
      transport.send(removeEvent);
    });

    test('ConsoleTransport log levels for listener events', () {
      final transport = ConsoleTransport();
      final reactive = LxVar(0);

      transport
          .send(ReactiveListenerAddedEvent(sessionId: 's', reactive: reactive));
      transport.send(
          ReactiveListenerRemovedEvent(sessionId: 's', reactive: reactive));
    });
  });
}
