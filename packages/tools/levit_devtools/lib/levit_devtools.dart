/// Loopback-only HTTP/WebSocket host for the read-only Levit inspector.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:path/path.dart' as path;

/// Read-only, IPv4-loopback inspector host with bounded sessions and delivery.
///
/// Producers connect to `/ws`; viewers select sessions through `/inspect`.
/// Reconnect snapshots restore current state, never a complete event history.
/// Await [close] to release sockets and finish pending HTTP requests.
class LevitInspectorServer {
  /// Directory containing the bundled Flutter web build.
  final Directory assets;

  /// Maximum retained sessions; connected producers remain pinned.
  final int maxSessions;

  /// Maximum retained event count per session.
  final int historyCapacity;

  /// Maximum retained encoded event bytes per session.
  final int historyBytes;

  /// Largest accepted producer envelope in UTF-8 bytes.
  final int maxMessageBytes;

  /// Maximum queued messages per viewer, excluding the acknowledged in-flight message.
  final int viewerQueueCapacity;
  final LinkedHashMap<String, _Session> _sessions = LinkedHashMap();
  final Set<WebSocket> _sockets = {};
  final Set<_Viewer> _viewers = {};
  final Set<Future<void>> _requests = {};
  final List<AsyncError> _failures = [];
  HttpServer? _server;
  Future<void>? _closing;
  LevitInspectorServer({
    required this.assets,
    this.maxSessions = 16,
    this.historyCapacity = 1000,
    this.historyBytes = 4 * 1024 * 1024,
    this.maxMessageBytes = 1024 * 1024,
    this.viewerQueueCapacity = 256,
  }) {
    for (final limit in [
      maxSessions,
      historyCapacity,
      historyBytes,
      maxMessageBytes,
      viewerQueueCapacity,
    ]) {
      if (limit < 1) {
        throw ArgumentError.value(limit, 'limit', 'Must be positive');
      }
    }
  }

  /// The bound port, available after [start] completes.
  int get port => _server!.port;

  /// The local browser URL, available after [start] completes.
  Uri get uri => Uri.parse('http://127.0.0.1:$port');

  /// Resolves assets inside the installed Dart package, independent of cwd.
  /// Embedded launchers may supply their package-URI [resolve] function.
  static Future<Directory> bundledAssets({
    Future<Uri?> Function(Uri) resolve = Isolate.resolvePackageUri,
  }) async {
    final location = await resolve(
      Uri.parse('package:levit_devtools/levit_devtools.dart'),
    );
    if (location == null) {
      throw StateError('Cannot locate bundled inspector assets.');
    }
    return Directory(path.join(path.dirname(location.toFilePath()), 'assets'));
  }

  /// Binds loopback (9200 by default); pass zero for an ephemeral test port.
  Future<void> start({int port = 9200}) async {
    if (_server != null || _closing != null) {
      throw StateError('Inspector already started or closed.');
    }
    if (!await File(path.join(assets.path, 'index.html')).exists()) {
      throw StateError(
        'Bundled inspector assets are missing. Run scripts/build_devtools.dart.',
      );
    }
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((request) {
      late Future<void> pending;
      pending = _serve(request)
          .catchError((Object error, StackTrace stack) async {
            _recordFailure(error, stack);
            try {
              request.response.statusCode = HttpStatus.internalServerError;
            } on StateError {
              // Streaming may already have committed headers. Finish/abort the
              // response without replacing the original failure with this one.
            }
            await _release(() async {
              await request.response.close();
            });
          })
          .whenComplete(() => _requests.remove(pending));
      _requests.add(pending);
    });
  }

  void _recordFailure(Object error, StackTrace stack) {
    if (_failures.length < 32) _failures.add(AsyncError(error, stack));
  }

  Future<void> _release(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      _recordFailure(error, stack);
    }
  }

  bool _allowedOrigin(HttpRequest request) {
    final raw = request.headers.value('origin');
    if (raw == null) return true;
    final origin = Uri.tryParse(raw);
    return origin != null &&
        {'http', 'https'}.contains(origin.scheme) &&
        {'localhost', '127.0.0.1', '[::1]', '::1'}.contains(origin.host);
  }

  Future<void> _serve(HttpRequest request) async {
    if (!_allowedOrigin(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    if (request.uri.path == '/ws' || request.uri.path == '/inspect') {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.pingInterval = const Duration(seconds: 15);
      if (request.uri.path == '/ws') {
        _producer(
          socket,
          request.uri.queryParameters['appId'] ?? 'application',
        );
      } else {
        _viewer(socket);
      }
      return;
    }
    if (request.uri.path == '/export') {
      final session = _sessions[request.uri.queryParameters['session']];
      request.response.headers.contentType = ContentType.json;
      if (session == null) {
        request.response.statusCode = 404;
      } else {
        request.response.headers.set(
          'Content-Disposition',
          'attachment; filename="levit-inspector.json"',
        );
        request.response.write(jsonEncode(session.frame()));
      }
      await request.response.close();
      return;
    }
    if (request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'status': 'ok', 'sessions': _sessions.length}),
      );
      await request.response.close();
      return;
    }
    final segments = request.uri.pathSegments;
    if (segments.any(
      (segment) =>
          segment == '..' || segment.contains('/') || segment.contains('\\'),
    )) {
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }
    final target = File(
      path.joinAll([
        assets.path,
        ...segments.isEmpty || request.uri.path == '/'
            ? ['index.html']
            : segments,
      ]),
    );
    if (!await target.exists()) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    request.response.headers.set('X-Content-Type-Options', 'nosniff');
    request.response.headers.set('Cache-Control', 'no-cache');
    request.response.headers.set('Content-Type', switch (path.extension(
      target.path,
    )) {
      '.html' => 'text/html; charset=utf-8',
      '.js' => 'application/javascript',
      '.json' => 'application/json',
      '.wasm' => 'application/wasm',
      '.css' => 'text/css',
      '.png' => 'image/png',
      '.woff2' => 'font/woff2',
      '.ttf' => 'font/ttf',
      _ => 'application/octet-stream',
    });
    await request.response.addStream(target.openRead());
    await request.response.close();
  }

  void _producer(WebSocket socket, String appId) {
    String? sessionId;
    socket.listen(
      (message) {
        if (message is! String ||
            utf8.encode(message).length > maxMessageBytes) {
          socket.close(1009, 'Event too large');
          return;
        }
        try {
          final data = Map<String, dynamic>.from(jsonDecode(message) as Map);
          if (data['sessionId'] is! String ||
              (data['sessionId'] as String).length > 128 ||
              data['seq'] is! int ||
              data['type'] is! String ||
              data['category'] is! String ||
              DateTime.tryParse(data['timestamp'].toString()) == null) {
            throw const FormatException('Invalid envelope');
          }
          final id = data['sessionId'] as String;
          if (sessionId != null && id != sessionId) {
            throw const FormatException(
              'Session cannot change on one connection',
            );
          }
          sessionId = id;
          var session = _sessions[id];
          if (session == null) {
            if (_sessions.length == maxSessions) {
              final inactive = _sessions.values
                  .where((entry) => entry.producer == null)
                  .firstOrNull;
              if (inactive == null) {
                socket.close(1008, 'Session capacity reached');
                return;
              }
              _sessions.remove(inactive.id);
            }
            session = _Session(
              id,
              appId.substring(0, appId.length.clamp(0, 128)),
              historyCapacity,
              historyBytes,
            );
            _sessions[id] = session;
          }
          final wasDisconnected = session.producer != socket;
          if (session.producer != null && session.producer != socket) {
            socket.close(1008, 'Session already connected');
            return;
          }
          session.producer = socket;
          final event = LevitEventEnvelope(_redact(data));
          final applied = session.apply(event);
          socket.add(jsonEncode({'ack': event.seq}));
          if (wasDisconnected) _broadcastSessions();
          if (applied) {
            for (final viewer in _viewers.where(
              (viewer) => viewer.selected == id,
            )) {
              viewer.send({
                'kind': 'event',
                'session': session.metadata(),
                'event': event.data,
              });
            }
          }
        } catch (_) {
          socket.close(1007, 'Invalid inspector envelope');
        }
      },
      onDone: () {
        _sockets.remove(socket);
        final session = _sessions[sessionId];
        if (session?.producer == socket) session!.producer = null;
        _broadcastSessions();
      },
    );
  }

  void _viewer(WebSocket socket) {
    final viewer = _Viewer(socket, viewerQueueCapacity);
    viewer.recovery = () {
      final session = _sessions[viewer.selected];
      return session == null
          ? _sessionList()
          : {...session.frame(), 'sessions': _sessionList()['sessions']};
    };
    _viewers.add(viewer);
    viewer.send(_sessionList());
    socket.listen(
      (message) {
        if (message is! String || message.length > 1024) {
          socket.close(1009);
          return;
        }
        try {
          final data = jsonDecode(message) as Map;
          if (data['ack'] is int) {
            viewer.acknowledge(data['ack'] as int);
            return;
          }
          final id = data['select'];
          if (id is String && _sessions.containsKey(id)) {
            viewer.selected = id;
            viewer.send(_sessions[id]!.frame());
          }
          // No command forwarding: inspector clients can only select and acknowledge.
        } catch (_) {
          socket.close(1007);
        }
      },
      onDone: () {
        viewer.dispose();
        _viewers.remove(viewer);
        _sockets.remove(socket);
      },
    );
  }

  Map<String, dynamic> _sessionList() => {
    'kind': 'sessions',
    'sessions': _sessions.values.map((session) => session.metadata()).toList(),
  };
  void _broadcastSessions() {
    for (final viewer in _viewers) {
      viewer.send(_sessionList());
    }
  }

  /// Idempotently disconnects viewers/producers and drains HTTP request cleanup.
  /// Reports retained request and cleanup failures after all release attempts.
  Future<void> close() => _closing ??= () async {
    for (final viewer in _viewers) {
      viewer.dispose();
    }
    await Future.wait(
      _sockets.toList().map(
        (socket) => _release(() async {
          await socket.close(1001, 'Inspector closed');
        }),
      ),
    );
    await _release(() async {
      await _server?.close(force: true);
    });
    await Future.wait(
      _requests.toList().map((request) => _release(() => request)),
    );
    _sockets.clear();
    _viewers.clear();
    if (_failures.isNotEmpty) throw LevitMonitorException(_failures);
  }();
}

Map<String, dynamic> _redact(Map<String, dynamic> data) {
  Object? visit(Object? value) {
    if (value is List) return value.map(visit).toList();
    if (value is Map) {
      final sensitive = value['isSensitive'] == true;
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          sensitive &&
                  {
                    'value',
                    'initialValue',
                    'oldValue',
                    'newValue',
                    'attributes',
                    'data',
                    'error',
                    'stack',
                    'stackTrace',
                  }.contains(key)
              ? '***'
              : visit(item),
        ),
      );
    }
    return value;
  }

  return Map<String, dynamic>.from(visit(data) as Map);
}

class _Session {
  final String id;
  final String appId;
  final int capacity;
  final int byteCapacity;
  final state = StateSnapshot();
  final ListQueue<LevitEventEnvelope> timeline = ListQueue();
  WebSocket? producer;
  int lastSequence = -1;
  int missingSequences = 0;
  int droppedHistory = 0;
  int bytes = 0;
  int producerDrops = 0;
  _Session(this.id, this.appId, this.capacity, this.byteCapacity);
  bool apply(LevitEventEnvelope event) {
    if (event.seq <= lastSequence) return false;
    if (lastSequence >= 0) missingSequences += event.seq - lastSequence - 1;
    lastSequence = event.seq;
    state.applyEnvelope(event);
    if (event.type == 'snapshot') {
      producerDrops =
          (event.data['state'] as Map)['droppedEvents'] as int? ?? 0;
      return true;
    }
    final size = utf8.encode(event.encode()).length;
    if (size > byteCapacity) {
      droppedHistory++;
      return true;
    }
    while (timeline.isNotEmpty &&
        (timeline.length >= capacity || bytes + size > byteCapacity)) {
      bytes -= utf8.encode(timeline.removeFirst().encode()).length;
      droppedHistory++;
    }
    timeline.add(event);
    bytes += size;
    return true;
  }

  Map<String, dynamic> metadata() => {
    'id': id,
    'appId': appId,
    'connected': producer != null,
    'lastSequence': lastSequence,
    'missingSequences': missingSequences,
    'droppedHistory': droppedHistory,
    'producerDrops': producerDrops,
    'historyComplete': false,
  };
  Map<String, dynamic> frame() => {
    'kind': 'snapshot',
    'session': metadata(),
    'state': state.toJson(),
    'timeline': timeline.map((event) => event.data).toList(),
    'historyComplete': false,
  };
}

class _Viewer {
  final WebSocket socket;
  final int capacity;
  final ListQueue<Map<String, dynamic>> _pending = ListQueue();
  int _sequence = 0;
  int? _inFlight;
  Timer? _timeout;
  String? selected;
  int dropped = 0;
  bool _disposed = false;
  late final Map<String, dynamic> Function() recovery;
  _Viewer(this.socket, this.capacity);
  void send(Map<String, dynamic> message) {
    if (_disposed) return;
    if (_pending.length == capacity) {
      dropped += _pending.length;
      _pending.clear();
      message = recovery();
    }
    _pending.add(message);
    _pump();
  }

  void _pump() {
    if (_inFlight != null || _pending.isEmpty || _disposed) return;
    final delivery = ++_sequence;
    _inFlight = delivery;
    socket.add(
      jsonEncode({
        ..._pending.removeFirst(),
        'delivery': delivery,
        'viewerDrops': dropped,
      }),
    );
    _timeout = Timer(const Duration(seconds: 5), () {
      socket.close(1008, 'Inspector acknowledgement timed out');
      dispose();
    });
  }

  void acknowledge(int delivery) {
    if (_inFlight != delivery) return;
    _timeout?.cancel();
    _inFlight = null;
    _pump();
  }

  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    _pending.clear();
  }
}
