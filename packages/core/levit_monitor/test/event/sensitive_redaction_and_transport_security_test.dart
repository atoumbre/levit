import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _RecordingTransport extends LevitTransport {
  final List<MonitorEvent> events = [];

  @override
  void send(MonitorEvent event) {
    events.add(event);
  }
}

class _FakeSink implements WebSocketSink {
  final _done = Completer<void>();

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<dynamic> get done => _done.future;
}

class _FakeChannel implements WebSocketChannel {
  final _incoming = StreamController<dynamic>.broadcast();
  final _sink = _FakeSink();

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Sensitive monitor redaction and transport hardening', () {
    late _RecordingTransport transport;

    setUp(() async {
      transport = _RecordingTransport();
      await LevitMonitor.attach(transport: transport, historyCapacity: 50);
      LevitMonitor.setObfuscator(null);
    });

    tearDown(() async {
      LevitMonitor.setObfuscator(null);
      await LevitMonitor.detach();
      await Levit.reset(force: true);
    });

    test(
      'LogEvent sensitive flag and nested sensitive reactives are redacted',
      () async {
        final secret = LxVar<String>('bearer-xyz', isSensitive: true);

        LevitMonitor.log(
          {'token': 'raw-secret'},
          sensitive: true,
          error: StateError('secret-error'),
          stackTrace: StackTrace.current,
        );
        LevitMonitor.log(secret);
        LevitMonitor.log({
          'nested': [secret],
        });
        LevitMonitor.emitCustomEvent(
          namespace: 'app.auth',
          name: 'check',
          attributes: {'secret': secret},
        );

        await LevitMonitor.flush();

        final serialized = transport.events
            .map((e) => e.toJson().toString())
            .join('\n');
        expect(serialized, isNot(contains('raw-secret')));
        expect(serialized, isNot(contains('secret-error')));
        expect(serialized, isNot(contains('bearer-xyz')));

        final sensitiveLog = transport.events
            .map((e) => e.toJson())
            .firstWhere((e) => e['type'] == 'log' && e['isSensitive'] == true);
        expect(sensitiveLog['data'], '***');
        expect(sensitiveLog['error'], '***');

        await secret.close();
      },
    );

    test(
      'ReactiveErrorEvent and listener events redact sensitive metadata',
      () {
        final secret = LxVar<String>('pw', isSensitive: true);
        final errorJson = ReactiveErrorEvent(
          sessionId: 's1',
          reactive: secret,
          error: StateError('leak'),
          stack: StackTrace.current,
        ).toJson();
        expect(errorJson['isSensitive'], isTrue);
        expect(errorJson['error'], '***');
        expect(errorJson['stack'], '***');

        final listenerJson = ReactiveListenerAddedEvent(
          sessionId: 's1',
          reactive: secret,
          context: const LxListenerContext(
            type: 'Widget',
            id: 1,
            data: {'secret': 'v'},
          ),
        ).toJson();
        expect(listenerJson['context'], '***');

        secret.close();
      },
    );

    test(
      'fluent sensitive() scrubs queued init event and snapshot history',
      () async {
        final token = LxVar<String>('fluent-secret').sensitive();
        await LevitMonitor.flush();

        final transportSerialized = transport.events
            .map((e) => e.toJson().toString())
            .join('\n');
        expect(transportSerialized, isNot(contains('fluent-secret')));

        final historySerialized = LevitMonitor.history
            .map((e) => e.data.toString())
            .join('\n');
        expect(historySerialized, isNot(contains('fluent-secret')));

        final nullable = LxVar<String?>(null).sensitive();
        await LevitMonitor.flush();
        final snapshotVars = LevitMonitor.snapshot!['variables'] as List;
        final nullableVar = snapshotVars.cast<Map>().firstWhere(
          (v) => v['id'] == nullable.id,
        );
        expect(nullableVar['value'], isNull);

        await token.close();
        await nullable.close();
      },
    );

    test('throwing custom obfuscator falls back to ***', () {
      LevitMonitor.setObfuscator((_) => throw StateError('broken obfuscator'));
      expect(LevitMonitor.obfuscate('secret'), '***');
    });

    test('middleware generates random 128-bit hex session IDs', () async {
      final m1 = LevitMonitorMiddleware(transport: _RecordingTransport());
      final m2 = LevitMonitorMiddleware(transport: _RecordingTransport());
      expect(m1.sessionId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(m2.sessionId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(m1.sessionId, isNot(m2.sessionId));
      await m1.close();
      await m2.close();
    });

    test(
      'WebSocketTransport blocks cleartext ws:// to non-loopback hosts by default',
      () async {
        expect(
          () => WebSocketTransport.connect(
            'ws://remote.example.com:9200/ws',
            channelBuilder: (_) => _FakeChannel(),
          ),
          throwsArgumentError,
        );

        final secure = WebSocketTransport.connect(
          'wss://remote.example.com:9200/ws',
          channelBuilder: (_) => _FakeChannel(),
        );
        await secure.close();

        final loopback = WebSocketTransport.connect(
          'ws://127.0.0.1:9200/ws',
          channelBuilder: (_) => _FakeChannel(),
        );
        await loopback.close();

        final optedIn = WebSocketTransport.connect(
          'ws://remote.example.com:9200/ws',
          allowInsecureRemote: true,
          channelBuilder: (_) => _FakeChannel(),
        );
        await optedIn.close();
      },
    );
  });
}
