import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('ConsoleTransport formats all events without crashing', () async {
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
      ReactiveGraphChangeEvent(sessionId: sid, reactive: rx, dependencies: []),
      ReactiveListenerAddedEvent(sessionId: sid, reactive: rx, context: null),
      ReactiveListenerRemovedEvent(sessionId: sid, reactive: rx, context: null),
      ReactiveErrorEvent(sessionId: sid, reactive: rx, error: 'err', stack: null),
      ScopeCreateEvent(sessionId: sid, scopeId: 1, scopeName: 's', parentScopeId: null),
      ScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's'),
      SnapshotEvent(sessionId: sid, state: {}),
      DependencyRegisterEvent(sessionId: sid, scopeId: 1, scopeName: 's', key: 'k', info: LevitDependency(), source: 'src'),
      DependencyResolveEvent(sessionId: sid, scopeId: 1, scopeName: 's', key: 'k', info: LevitDependency(), source: 'src'),
      DependencyDeleteEvent(sessionId: sid, scopeId: 1, scopeName: 's', key: 'k', info: LevitDependency(), source: 'src'),
      DependencyInstanceCreateEvent(sessionId: sid, scopeId: 1, scopeName: 's', key: 'k', info: LevitDependency()),
      DependencyInstanceReadyEvent(sessionId: sid, scopeId: 1, scopeName: 's', key: 'k', info: LevitDependency(), instance: 'ready'),
    ];

    for (final event in events) {
      transport.send(event);
      event.toJson();
    }
    await transport.close();
  });
}
