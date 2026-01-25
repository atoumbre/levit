import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMonitor Coverage', () {
    test('ReactiveListenerAddedEvent.toJson includes context', () {
      final reactive = LxVar(0, name: 'test_var');
      final event = ReactiveListenerAddedEvent(
        sessionId: 'session_1',
        reactive: reactive,
        context: const LxListenerContext(
            type: 'Test', id: 123, data: {'foo': 'bar'}),
      );

      final json = event.toJson();
      expect(json['type'], 'listener_add');
      expect(json['sessionId'], 'session_1');
      expect(json['context'], {
        'type': 'Test',
        'id': 123,
        'data': {'foo': 'bar'}
      });
    });

    test('ReactiveListenerRemovedEvent.toJson includes context', () {
      final reactive = LxVar(0, name: 'test_var');
      final event = ReactiveListenerRemovedEvent(
        sessionId: 'session_1',
        reactive: reactive,
        context: const LxListenerContext(
            type: 'Test', id: 123, data: {'foo': 'bar'}),
      );

      final json = event.toJson();
      expect(json['type'], 'listener_remove');
      expect(json['sessionId'], 'session_1');
      expect(json['context'], {
        'type': 'Test',
        'id': 123,
        'data': {'foo': 'bar'}
      });
    });

    test('ConsoleTransport formats listener events', () {
      // We can't easily capture print output, but we can verify the private _formatMessage
      // if we could access it, or just run it to ensure no exceptions and hit lines.
      // Since it's private, we'll trust that running 'send' triggers it.
      // We'll subclass to expose/verify if possible, or just call send.

      final transport = ConsoleTransport(); // Default uses print
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

      // This should just not throw and hit the lines
      transport.send(addEvent);
      transport.send(removeEvent);
    });

    test('ConsoleTransport log levels for listener events', () {
      final transport = ConsoleTransport();
      final reactive = LxVar(0);

      // To verify the switch case in _getLogLevel, we send events.
      // We can't assert the result directly as it's private, but execution covers the lines.
      transport
          .send(ReactiveListenerAddedEvent(sessionId: 's', reactive: reactive));
      transport.send(
          ReactiveListenerRemovedEvent(sessionId: 's', reactive: reactive));
    });
  });
}
