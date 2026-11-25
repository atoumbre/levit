import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:levit_devtools/levit_devtools.dart';
import 'package:test/test.dart';

void main() {
  late Directory assets;
  late LevitInspectorServer server;
  setUp(() async {
    assets = await Directory.systemTemp.createTemp('levit-inspector-test-');
    await File(
      '${assets.path}/index.html',
    ).writeAsString('<title>Levit Inspector</title>');
    server = LevitInspectorServer(
      assets: assets,
      historyCapacity: 3,
      viewerQueueCapacity: 2,
    );
    await server.start(port: 0);
  });
  tearDown(() async {
    await server.close();
    await assets.delete(recursive: true);
  });
  test(
    'compact ownership is complete without earlier lifecycle events',
    () async {
      final producer = await _Peer.connect(server, '/ws');
      await producer.emit(
        _event('app', 12, 'scope_progress', {
          'version': 1,
          'scope': [
            1,
            'feature',
            1,
            2,
            [
              [2, 'root'],
            ],
            [],
            [
              ['Repo', 'Repo', null, 48, 2, 1],
            ],
          ],
        }, category: 'di'),
      );
      final export =
          jsonDecode(
                (await _get(server.uri.resolve('/export?session=app'))).body,
              )
              as Map;
      final scope = (export['state']['scopes'] as List).single as Map;
      expect(scope['name'], 'feature');
      expect(scope['parentScopeId'], 2);
      expect(scope['progress']['pendingInitializations'], 2);
      expect(scope['progress']['isClosing'], true);
      expect(scope['progress']['registrations'][0]['isInstantiated'], true);
      final viewer = await _Peer.connect(server, '/inspect', ack: true);
      viewer.send({'select': 'app'});
      final restored = await viewer.next(
        (message) => message['kind'] == 'snapshot',
      );
      expect(restored['state']['scopes'], [scope]);
      await viewer.close();
      await producer.close();
    },
  );
  test('two sessions, immutable redacted export and reconnect state', () async {
    final app = await _Peer.connect(server, '/ws?appId=nexus-studio');
    final backend = await _Peer.connect(server, '/ws?appId=nexus-server');
    final viewer = await _Peer.connect(server, '/inspect', ack: true);
    await app.emit(
      _event('app', 0, 'scope_create', {
        'scopeId': 1,
        'scopeName': 'project',
        'parentScopeId': null,
      }, category: 'di'),
    );
    await backend.emit(
      _event('server', 0, 'scope_create', {
        'scopeId': 2,
        'scopeName': 'server',
        'parentScopeId': null,
      }, category: 'di'),
    );
    final sessions = await viewer.next(
      (message) =>
          message['kind'] == 'sessions' &&
          (message['sessions'] as List).length == 2,
    );
    expect(
      (sessions['sessions'] as List).map((session) => session['appId']),
      containsAll(['nexus-studio', 'nexus-server']),
    );
    viewer.send({'select': 'app'});
    await viewer.next((message) => message['kind'] == 'snapshot');
    await app.emit(
      _event('app', 1, 'reactive_init', {
        'reactiveId': '7',
        'name': 'password',
        'isSensitive': true,
        'initialValue': 'secret',
        'valueType': 'String',
        'ownerId': '1:Controller',
      }),
    );
    final live = await viewer.next((message) => message['kind'] == 'event');
    expect(jsonEncode(live), isNot(contains('secret')));
    for (var seq = 2; seq < 7; seq++) {
      await app.emit(
        _event('app', seq, 'state_change', {
          'reactiveId': '7',
          'isSensitive': true,
          'newValue': 'secret-$seq',
          'oldValue': 'secret',
          'valueType': 'String',
        }),
      );
    }
    final export = await _get(server.uri.resolve('/export?session=app'));
    final saved = jsonDecode(export.body) as Map;
    expect((saved['timeline'] as List).length, 3);
    expect(saved['session']['droppedHistory'], greaterThan(0));
    expect(export.body, isNot(contains('secret')));
    expect(saved['historyComplete'], isFalse);
    await app.close();
    await viewer.next(
      (message) =>
          message['kind'] == 'sessions' &&
          (message['sessions'] as List).any(
            (session) =>
                session['id'] == 'app' && session['connected'] == false,
          ),
    );
    final reconnect = await _Peer.connect(server, '/ws?appId=nexus-studio');
    await reconnect.emit(
      _event('app', 10, 'snapshot', {
        'state': {
          'scopes': [],
          'dependencies': [],
          'variables': [],
          'droppedEvents': 2,
          'historyComplete': false,
        },
      }, category: 'snapshot'),
    );
    final restored =
        jsonDecode((await _get(server.uri.resolve('/export?session=app'))).body)
            as Map;
    expect(restored['state']['scopes'], isEmpty);
    expect(restored['state']['variables'], isEmpty);
    expect(restored['session']['producerDrops'], 2);
    expect(restored['session']['missingSequences'], 3);
    await reconnect.close();
    await backend.close();
    await viewer.close();
  });
  test('slow viewer overflow recovers from a current snapshot', () async {
    final producer = await _Peer.connect(server, '/ws');
    await producer.emit(
      _event('app', 0, 'scope_create', {
        'scopeId': 1,
        'scopeName': 'root',
      }, category: 'di'),
    );
    final viewer = await _Peer.connect(server, '/inspect');
    final sessions = await viewer.next(
      (message) => message['kind'] == 'sessions',
    );
    viewer.send({'ack': sessions['delivery']});
    viewer.send({'select': 'app'});
    final first = await viewer.next((message) => message['kind'] == 'snapshot');
    for (var seq = 1; seq <= 8; seq++) {
      await producer.emit(
        _event('app', seq, 'state_change', {
          'reactiveId': '3',
          'name': 'count',
          'isSensitive': false,
          'newValue': '$seq',
          'valueType': 'int',
        }),
      );
    }
    // Membership changes can overflow a queued delta too. Recovery must retain
    // the selected state as well as the current session list.
    final other = await _Peer.connect(server, '/ws?appId=other');
    await other.emit(
      _event('other', 0, 'scope_create', {
        'scopeId': 2,
        'scopeName': 'other',
      }, category: 'di'),
    );
    viewer.send({'ack': first['delivery']});
    final recovery = await viewer.next(
      (message) => message['kind'] == 'snapshot',
    );
    expect(recovery['viewerDrops'], greaterThan(0));
    expect(
      (recovery['state']['variables'] as List).single['value'],
      anyOf('7', '8'),
    );
    await other.close();
    await producer.close();
    await viewer.close();
  });
  test(
    'server is read-only, loopback-bound and rejects remote browser origins',
    () async {
      expect((await _get(server.uri)).body, contains('Levit Inspector'));
      expect((await _get(server.uri.resolve('/health'))).status, 200);
      final client = HttpClient();
      final remote = await client.getUrl(server.uri);
      remote.headers.set('Origin', 'https://untrusted.example');
      final denied = await remote.close();
      expect(denied.statusCode, 403);
      await denied.drain<void>();
      final post = await client.postUrl(server.uri.resolve('/command'));
      final response = await post.close();
      expect(response.statusCode, 405);
      await response.drain<void>();
      client.close(force: true);
      expect(server.uri.host, '127.0.0.1');
    },
  );

  test('startup guards and asset responses are deterministic', () async {
    expect(
      () => LevitInspectorServer(assets: assets, historyCapacity: 0),
      throwsArgumentError,
    );
    await expectLater(server.start(port: 0), throwsStateError);
    final absent = LevitInspectorServer(
      assets: Directory('${assets.path}/absent'),
    );
    await expectLater(absent.start(port: 0), throwsStateError);
    await absent.close();
    await expectLater(absent.start(port: 0), throwsStateError);
    expect((await _get(server.uri.resolve('/missing'))).status, 404);
    expect(
      (await _get(server.uri.resolve('/export?session=missing'))).status,
      404,
    );
    expect((await _get(server.uri.resolve('/ws'))).status, 400);
    expect((await _get(server.uri.resolve('/a%2Fb'))).status, 403);
    expect((await _get(server.uri.resolve('/a%5Cb'))).status, 403);
    for (final type in {
      'js': 'application/javascript',
      'json': 'application/json',
      'wasm': 'application/wasm',
      'css': 'text/css',
      'png': 'image/png',
      'woff2': 'font/woff2',
      'ttf': 'font/ttf',
      'bin': 'application/octet-stream',
    }.entries) {
      await File('${assets.path}/asset.${type.key}').writeAsString('asset');
      final client = HttpClient();
      final response = await (await client.getUrl(
        server.uri.resolve('/asset.${type.key}'),
      )).close();
      expect(response.headers.contentType!.mimeType, type.value);
      expect(response.headers.value('X-Content-Type-Options'), 'nosniff');
      await response.drain<void>();
      client.close(force: true);
    }
  });

  test(
    'session capacity pins live producers and evicts disconnected sessions',
    () async {
      await server.close();
      server = LevitInspectorServer(assets: assets, maxSessions: 1);
      await server.start(port: 0);
      final first = await _Peer.connect(server, '/ws');
      await first.emit(_event('first', 0, 'log', {}));
      final full = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws');
      full.add(jsonEncode(_event('second', 0, 'log', {})));
      await full.drain<void>();
      expect(full.closeCode, 1008);
      expect(full.closeReason, 'Session capacity reached');
      final duplicate = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws',
      );
      duplicate.add(jsonEncode(_event('first', 1, 'log', {})));
      await duplicate.drain<void>();
      expect(duplicate.closeCode, 1008);
      final observer = await _Peer.connect(server, '/inspect', ack: true);
      await observer.next((m) => m['kind'] == 'sessions');
      await first.close();
      await observer.next(
        (m) => (m['sessions'] as List).single['connected'] == false,
      );
      final next = await _Peer.connect(server, '/ws');
      await next.emit(_event('second', 0, 'log', {}));
      expect(
        (await _get(server.uri.resolve('/export?session=first'))).status,
        404,
      );
      expect(
        (await _get(server.uri.resolve('/export?session=second'))).status,
        200,
      );
      await next.close();
      await observer.close();
    },
  );

  test(
    'duplicate sequence is acknowledged once and oversized history retains current state',
    () async {
      await server.close();
      server = LevitInspectorServer(assets: assets, historyBytes: 10);
      await server.start(port: 0);
      final producer = await _Peer.connect(server, '/ws');
      final event = _event('app', 1, 'reactive_init', {
        'reactiveId': '1',
        'initialValue': 'current',
        'valueType': 'String',
      });
      await producer.emit(event);
      await producer.emit(event);
      final state =
          jsonDecode(
                (await _get(server.uri.resolve('/export?session=app'))).body,
              )
              as Map;
      expect(state['session']['droppedHistory'], 1);
      expect(state['timeline'], isEmpty);
      expect((state['state']['variables'] as List).single['value'], 'current');
      await producer.close();
    },
  );

  for (final endpoint in ['/ws', '/inspect']) {
    for (final malformed in [
      '{bad',
      <int>[1, 2, 3],
    ]) {
      test(
        '$endpoint rejects malformed ${malformed.runtimeType} frames',
        () async {
          final socket = await WebSocket.connect(
            'ws://127.0.0.1:${server.port}$endpoint',
          );
          socket.add(malformed);
          await socket.drain<void>();
          expect(socket.closeCode, malformed is String ? 1007 : 1009);
        },
      );
    }
  }

  test(
    'producer envelope validation rejects missing fields and changed session identities',
    () async {
      final invalid = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws',
      );
      invalid.add(jsonEncode({'sessionId': 'invalid'}));
      await invalid.drain<void>();
      expect(invalid.closeCode, 1007);
      final peer = await _Peer.connect(server, '/ws');
      await peer.emit(_event('first', 0, 'log', {}));
      peer.send(_event('second', 1, 'log', {}));
      await expectLater(peer.next((_) => false), throwsStateError);
      expect(peer.socket.closeCode, 1007);
      await peer.close();
    },
  );

  test(
    'slow unselected viewer recovers session membership and times out without ack',
    () async {
      final viewer = await _Peer.connect(server, '/inspect');
      final first = await viewer.next((m) => m['kind'] == 'sessions');
      final producers = <_Peer>[];
      for (var i = 0; i < 4; i++) {
        final producer = await _Peer.connect(server, '/ws');
        producers.add(producer);
        await producer.emit(_event('session$i', 0, 'log', {}));
      }
      viewer.send({'ack': -1});
      viewer.send({'ack': first['delivery']});
      final recovery = await viewer.next((m) => m['kind'] == 'sessions');
      expect(recovery['viewerDrops'], greaterThan(0));
      expect((recovery['sessions'] as List).length, greaterThanOrEqualTo(3));
      await expectLater(viewer.next((_) => false), throwsStateError);
      expect(viewer.socket.closeCode, 1008);
      for (final producer in producers) {
        await producer.close();
      }
      await viewer.close();
    },
  );
}

Map<String, dynamic> _event(
  String session,
  int seq,
  String type,
  Map<String, dynamic> values, {
  String category = 'state',
}) => {
  'sessionId': session,
  'seq': seq,
  'timestamp': DateTime.now().toIso8601String(),
  'type': type,
  'category': category,
  ...values,
};
Future<({int status, String body})> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    return (
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  } finally {
    client.close(force: true);
  }
}

class _Peer {
  final WebSocket socket;
  final _messages = StreamController<Map<String, dynamic>>();
  late final StreamIterator<Map<String, dynamic>> _iterator;
  _Peer(this.socket, bool ack) {
    _iterator = StreamIterator(_messages.stream);
    socket.listen((raw) {
      final message = Map<String, dynamic>.from(
        jsonDecode(raw as String) as Map,
      );
      if (ack && message['delivery'] != null) {
        send({'ack': message['delivery']});
      }
      _messages.add(message);
    }, onDone: _messages.close);
  }
  static Future<_Peer> connect(
    LevitInspectorServer server,
    String suffix, {
    bool ack = false,
  }) async => _Peer(
    await WebSocket.connect('ws://127.0.0.1:${server.port}$suffix'),
    ack,
  );
  void send(Map<String, dynamic> message) => socket.add(jsonEncode(message));
  Future<Map<String, dynamic>> next(
    bool Function(Map<String, dynamic>) predicate,
  ) async {
    while (await _iterator.moveNext()) {
      if (predicate(_iterator.current)) return _iterator.current;
    }
    throw StateError('Connection closed before expected message');
  }

  Future<void> emit(Map<String, dynamic> event) async {
    send(event);
    await next((message) => message['ack'] == event['seq']);
  }

  Future<void> close() async {
    await _iterator.cancel();
    await socket.close();
  }
}
