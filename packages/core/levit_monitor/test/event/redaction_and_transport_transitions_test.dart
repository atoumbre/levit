import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/spi.dart';
import 'package:test/test.dart';

class _BlockingSendTransport extends LevitTransport {
  final Completer<void> sendStarted = Completer<void>();
  final Completer<void> releaseSend = Completer<void>();
  final List<LevitMonitorEvent> events = [];

  @override
  Future<void> send(LevitMonitorEvent event) async {
    events.add(event);
    if (!sendStarted.isCompleted) sendStarted.complete();
    await releaseSend.future;
  }
}

void main() {
  tearDown(() async {
    await LevitMonitor.detach();
    LevitMonitor.setFilter(null);
    LevitMonitor.setObfuscator(null);
    LevitMonitor.setLogLevel(LevitLogLevel.all);
    await Levit.reset(force: true);
  });

  group(
    'Sensitive redaction in nested maps, listener events, and batch history',
    () {
      test(
        'redacts sensitive reactive map keys during event serialization',
        () {
          final secretKey = LxVar('api-secret-key', isSensitive: true);
          final container = LxVar<Map<Object, Object?>>({
            secretKey: 'visible-value',
          });
          final event = LevitReactiveInitEvent(
            sessionId: 's1',
            reactive: container,
          );

          final encoded = event.toJson()['initialValue'] as String;
          expect(encoded, isNot(contains('api-secret-key')));
          expect(encoded, contains('***'));

          container.close();
          secretKey.close();
        },
      );

      test(
        'redacts listener context on LevitReactiveListenerRemovedEvent when sensitive',
        () {
          final secret = LxVar('token', isSensitive: true);
          final context = LxListenerContext(
            type: 'Widget',
            id: 1,
            data: {'token': 'secret'},
          );

          final withContext = LevitReactiveListenerRemovedEvent(
            sessionId: 's1',
            reactive: secret,
            context: context,
          ).toJson();
          expect(withContext['context'], '***');

          final withoutContext = LevitReactiveListenerRemovedEvent(
            sessionId: 's1',
            reactive: secret,
          ).toJson();
          expect(withoutContext['context'], isNull);

          secret.close();
        },
      );

      test(
        'redacts unredacted incoming updates for sensitive reactive models',
        () {
          final snapshot = LevitStateSnapshot(maxEvents: 10);
          snapshot.applyEnvelope(
            LevitEventEnvelope({
              'seq': 1,
              'timestamp': DateTime.now().toIso8601String(),
              'sessionId': 's1',
              'type': 'reactive_init',
              'category': 'state',
              'reactiveId': '42',
              'name': 'secret',
              'isSensitive': true,
              'initialValue': '***',
              'valueType': 'String',
            }),
          );

          snapshot.applyEnvelope(
            LevitEventEnvelope({
              'seq': 2,
              'timestamp': DateTime.now().toIso8601String(),
              'sessionId': 's1',
              'type': 'state_change',
              'category': 'state',
              'reactiveId': '42',
              'newValue': 'leaked-secret',
              'valueType': 'String',
            }),
          );

          expect(snapshot.variables[42]?.value, '***');
        },
      );

      test(
        'scrubSensitiveReactive redacts matching batch entries and preserves others',
        () {
          final snapshot = LevitStateSnapshot(maxEvents: 10);
          snapshot.applyEnvelope(
            LevitEventEnvelope({
              'seq': 1,
              'timestamp': DateTime.now().toIso8601String(),
              'sessionId': 's1',
              'type': 'batch',
              'category': 'state',
              'entries': [
                {
                  'reactiveId': '10',
                  'isSensitive': false,
                  'oldValue': 'old-secret',
                  'newValue': 'new-secret',
                },
                {
                  'reactiveId': '11',
                  'isSensitive': false,
                  'oldValue': 'keep-old',
                  'newValue': 'keep-new',
                },
              ],
            }),
          );
          snapshot.applyEnvelope(
            LevitEventEnvelope({
              'seq': 2,
              'timestamp': DateTime.now().toIso8601String(),
              'sessionId': 's1',
              'type': 'batch',
              'category': 'state',
              'entries': [
                {'reactiveId': '99', 'oldValue': 'x', 'newValue': 'y'},
              ],
            }),
          );

          snapshot.scrubSensitiveReactive('10');

          final batchEntries = snapshot.events.first.data['entries'] as List;
          final scrubbed = batchEntries[0] as Map;
          final untouched = batchEntries[1] as Map;
          expect(scrubbed['isSensitive'], isTrue);
          expect(scrubbed['oldValue'], '***');
          expect(scrubbed['newValue'], '***');
          expect(untouched['oldValue'], 'keep-old');
          expect(untouched['newValue'], 'keep-new');
        },
      );
    },
  );

  group('WebSocket URL scheme validation and transport transitions', () {
    test('rejects non-ws and non-wss URL schemes', () {
      expect(
        () => LevitWebSocketTransport.connect('http://127.0.0.1:9200/ws'),
        throwsArgumentError,
      );
    });

    test(
      'concurrent flush waits for paused transport update transition',
      () async {
        final first = _BlockingSendTransport();
        final second = _BlockingSendTransport()..releaseSend.complete();
        final middleware = LevitMonitorMiddleware(transport: first);
        middleware.enable();

        final counter = 0.lx;
        counter.value = 1;
        await first.sendStarted.future;

        // flush() enters _flushQueue and awaits _pumping while first.send is in flight.
        final flushing = middleware.flush();
        await Future<void>.delayed(Duration.zero);

        // updateTransport pauses pumping while an extra event stays queued.
        final updating = middleware.updateTransport(transport: second);
        counter.value = 2;
        await Future<void>.delayed(Duration.zero);

        first.releaseSend.complete();
        await Future.wait([updating, flushing]);

        await middleware.close();
        await counter.close();
      },
    );
  });

  group('Console transport raw event level dispatch', () {
    test(
      'handles raw init, dependency register/resolve, and error events',
      () async {
        final lines = <String>[];
        final transport = LevitConsoleTransport(
          minLevel: LevitLogLevel.trace,
          levelOverrides: const LevitLogLevelConfig(
            reactiveInit: LevitLogLevel.info,
            diRegister: LevitLogLevel.debug,
            diResolve: LevitLogLevel.info,
            reactiveError: LevitLogLevel.fatal,
          ),
          formatter: (_, message) => message,
          output: lines.add,
        );
        final reactive = 1.lx.named('count');
        final dep = LevitDependency<int>(instance: 1);

        transport.send(
          LevitReactiveInitEvent(sessionId: 's1', reactive: reactive),
        );
        transport.send(
          LevitDependencyRegisterEvent(
            sessionId: 's1',
            scopeId: 1,
            scopeName: 'root',
            key: 'int',
            info: dep,
            source: 'put',
          ),
        );
        transport.send(
          LevitDependencyResolveEvent(
            sessionId: 's1',
            scopeId: 1,
            scopeName: 'root',
            key: 'int',
            info: dep,
            source: 'find',
          ),
        );
        transport.send(
          LevitReactiveErrorEvent(
            sessionId: 's1',
            reactive: reactive,
            error: StateError('boom'),
          ),
        );

        expect(lines, hasLength(4));
        await transport.close();
        await reactive.close();
      },
    );
  });
}
