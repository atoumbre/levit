import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  group('Levit Monitor Full Coverage', () {
    test('ConsoleTransport formatting and levels', () async {
      final transport = ConsoleTransport();
      final sid = 'session';
      final rx = 0.lx.named('test_rx');
      final change = LevitReactiveChange(
        timestamp: DateTime.now(),
        valueType: int,
        oldValue: 0,
        newValue: 1,
      );

      final events = [
        ReactiveInitEvent(sessionId: sid, reactive: rx),
        ReactiveChangeEvent(sessionId: sid, reactive: rx, change: change),
        ReactiveBatchEvent(sessionId: sid, change: LevitReactiveBatch([])),
        ReactiveDisposeEvent(sessionId: sid, reactive: rx),
        ReactiveGraphChangeEvent(
            sessionId: sid, reactive: rx, dependencies: []),
        ReactiveListenerAddedEvent(sessionId: sid, reactive: rx, context: null),
        ReactiveListenerRemovedEvent(
            sessionId: sid, reactive: rx, context: null),
        ReactiveErrorEvent(
            sessionId: sid, reactive: rx, error: 'err', stack: null),
        ScopeCreateEvent(
            sessionId: sid, scopeId: 1, scopeName: 's', parentScopeId: null),
        ScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's'),
        SnapshotEvent(sessionId: sid, state: {}),
        DependencyRegisterEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's',
          key: 'k',
          info: LevitDependency(),
          source: 'src',
        ),
        DependencyResolveEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's',
          key: 'k',
          info: LevitDependency(),
          source: 'src',
        ),
        DependencyDeleteEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's',
          key: 'k',
          info: LevitDependency(),
          source: 'src',
        ),
        DependencyInstanceCreateEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's',
          key: 'k',
          info: LevitDependency(),
        ),
        DependencyInstanceReadyEvent(
          sessionId: sid,
          scopeId: 1,
          scopeName: 's',
          key: 'k',
          info: LevitDependency(),
          instance: 'ready',
        ),
      ];

      for (final event in events) {
        // Just verify it doesn't crash during formatting/sending
        transport.send(event);
        // Call toJson to ensure coverage for serialization paths
        event.toJson();
      }
      await transport.close();
    });

    test('LevitMonitorMiddleware snapshot sync on connect', () async {
      final transport = MockTransport();
      final middleware = LevitMonitorMiddleware(transport: transport);

      middleware.enable();

      transport.onConnectController.add(null);

      await Future.delayed(Duration(milliseconds: 10));
      expect(transport.sentEvents.any((e) => e is SnapshotEvent), isTrue);

      middleware.disable();
      await middleware.close();
    });

    test('MonitorEvent stringify fallback', () {
      final unprintable = Unprintable();
      final event = ReactiveErrorEvent(sessionId: 's', error: unprintable);
      expect(event.toJson()['error'], contains('<unprintable>'));
    });

    test('LevitTransport default onConnect', () {
      final t = StubTransport();
      expect(t.onConnect, isNotNull);
    });
  });
}

class MockTransport extends LevitTransport {
  final sentEvents = <MonitorEvent>[];
  final onConnectController = StreamController<void>.broadcast();

  @override
  void send(MonitorEvent event) => sentEvents.add(event);

  @override
  Stream<void> get onConnect => onConnectController.stream;

  @override
  Future<void> close() async {
    await onConnectController.close();
  }
}

class StubTransport extends LevitTransport {
  @override
  void send(MonitorEvent event) {}
}

class Unprintable {
  @override
  String toString() => throw Exception('Cannot stringify');
}
