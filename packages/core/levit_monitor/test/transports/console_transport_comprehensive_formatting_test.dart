import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  test('LevitConsoleTransport formats all events without crashing', () async {
    final transport = LevitConsoleTransport();
    final sid = 'session';
    final rx = 0.lx.named('test_rx');
    final change = LevitReactiveChange(
      timestamp: DateTime.now(),
      valueType: int,
      oldValue: 0,
      newValue: 1,
    );

    final events = [
      LevitReactiveInitEvent(sessionId: sid, reactive: rx),
      LevitReactiveChangeEvent(sessionId: sid, reactive: rx, change: change),
      LevitReactiveBatchEvent(sessionId: sid, change: LevitReactiveBatch([])),
      LevitReactiveDisposeEvent(sessionId: sid, reactive: rx),
      LevitReactiveGraphChangeEvent(
        sessionId: sid,
        reactive: rx,
        dependencies: [],
      ),
      LevitReactiveListenerAddedEvent(
        sessionId: sid,
        reactive: rx,
        context: null,
      ),
      LevitReactiveListenerRemovedEvent(
        sessionId: sid,
        reactive: rx,
        context: null,
      ),
      LevitReactiveErrorEvent(
        sessionId: sid,
        reactive: rx,
        error: 'err',
        stack: null,
      ),
      LevitScopeCreateEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        parentScopeId: null,
      ),
      LevitScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's'),
      LevitSnapshotEvent(sessionId: sid, state: {}),
      LevitDependencyRegisterEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        key: 'k',
        info: LevitDependency(),
        source: 'src',
      ),
      LevitDependencyResolveEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        key: 'k',
        info: LevitDependency(),
        source: 'src',
      ),
      LevitDependencyDeleteEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        key: 'k',
        info: LevitDependency(),
        source: 'src',
      ),
      LevitDependencyInstanceCreateEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        key: 'k',
        info: LevitDependency(),
      ),
      LevitDependencyInstanceReadyEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's',
        key: 'k',
        info: LevitDependency(),
        instance: 'ready',
      ),
    ];

    for (final event in events) {
      transport.send(event);
      event.toJson();
    }
    await transport.close();
  });
}
