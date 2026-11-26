import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_monitor/spi.dart';

import 'config.dart';
import 'security.dart';
import 'session_store.dart';

/// Authenticated loopback WebSocket relay receiving `levit_monitor` telemetry.
///
/// {@category Relay & Security}
final class LevitWebSocketRelay {
  /// Relay port, authentication token, origin allowlist, and frame limits.
  final LevitMcpConfig config;

  /// Bounded session store updated as producer envelopes arrive.
  final LevitSessionStore store;
  final HttpServer _server;
  final Map<Object, Future<void> Function([int? code])> _activeConnections = {};
  final Set<StreamSubscription<dynamic>> _subscriptions = {};
  bool _closed = false;
  int _fallbackSessionCounter = 0;

  LevitWebSocketRelay._(this.config, this.store, this._server) {
    _server.listen(_handleRequest);
  }

  /// Starts listening on `127.0.0.1` at [LevitMcpConfig.port].
  ///
  /// Incoming HTTP requests on `/ws` are validated in order:
  /// 1. `Host` header via [LevitRelaySecurity.isValidLoopbackHost] (`403` on
  ///    failure).
  /// 2. Path equals `/ws` (`404` otherwise).
  /// 3. `Origin` header via [LevitRelaySecurity.isAllowedOrigin] (`403` on
  ///    failure).
  /// 4. Authentication token via [LevitRelaySecurity.isAuthorized] (`401` on
  ///    failure).
  /// 5. Active connections below [LevitMcpConfig.maxConnections] (`503` when
  ///    full).
  /// 6. Valid WebSocket upgrade request (`400` otherwise).
  static Future<LevitWebSocketRelay> bind({
    required LevitMcpConfig config,
    required LevitSessionStore store,
  }) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      config.port,
    );
    return LevitWebSocketRelay._(config, store, server);
  }

  /// Bound TCP port on `127.0.0.1`.
  int get port => _server.port;

  /// Loopback WebSocket endpoint URI (without authentication query parameter).
  Uri get wsUri =>
      Uri(scheme: 'ws', host: '127.0.0.1', port: port, path: '/ws');

  /// Number of currently connected producer WebSockets.
  int get activeConnections => _activeConnections.length;

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');

    if (!LevitRelaySecurity.isValidLoopbackHost(
      request.headers[HttpHeaders.hostHeader],
      port,
    )) {
      await _reject(response, HttpStatus.forbidden, 'Invalid Host header.');
      return;
    }

    if (request.uri.path != '/ws') {
      await _reject(response, HttpStatus.notFound, 'Not found.');
      return;
    }

    if (!LevitRelaySecurity.isAllowedOrigin(
      request.headers['origin'],
      config.allowWebOrigins,
    )) {
      await _reject(response, HttpStatus.forbidden, 'Origin not allowed.');
      return;
    }

    if (!LevitRelaySecurity.isAuthorized(
      authorizationHeaders: request.headers[HttpHeaders.authorizationHeader],
      queryToken: request.uri.queryParameters['token'],
      expectedToken: config.token,
    )) {
      await _reject(response, HttpStatus.unauthorized, 'Unauthorized.');
      return;
    }

    if (_activeConnections.length >= config.maxConnections) {
      await _reject(
        response,
        HttpStatus.serviceUnavailable,
        'Connection capacity reached.',
      );
      return;
    }

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      await _reject(
        response,
        HttpStatus.badRequest,
        'WebSocket upgrade required.',
      );
      return;
    }

    final appId = request.uri.queryParameters['appId'];
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
    } catch (_) {
      return;
    }

    attachProducerStream(
      stream: socket,
      send: socket.add,
      closeConnection: ([code]) => socket.close(code),
      appId: appId,
    );
  }

  /// Attaches a decoded message stream as a monitored producer connection.
  ///
  /// Exposed for testing and custom transports; normal traffic arrives via
  /// WebSocket upgrades on `/ws`.
  ///
  /// Wire-protocol handling for each incoming frame:
  /// - Non-`String` frames close the connection with
  ///   `WebSocketStatus.unsupportedData` (`1003`).
  /// - UTF-8 payloads exceeding [LevitMcpConfig.maxMessageBytes] close with
  ///   `WebSocketStatus.messageTooBig` (`1009`).
  /// - Malformed JSON, non-object envelopes, or session-capacity errors close
  ///   with `WebSocketStatus.policyViolation` (`1008`).
  /// - Envelopes without a non-empty `sessionId` are assigned a fallback
  ///   `session-<N>` identifier for the lifetime of the connection.
  /// - Envelopes carrying an integer `seq` trigger an `{"ack": seq}` reply via
  ///   [send].
  /// - Stream completion or error marks the bound session disconnected in
  ///   [store].
  void attachProducerStream({
    required Stream<dynamic> stream,
    required void Function(String payload) send,
    required Future<void> Function([int? code]) closeConnection,
    String? appId,
  }) {
    final connectionKey = Object();
    _activeConnections[connectionKey] = closeConnection;
    String? boundSessionId;
    var released = false;

    void release([int? code]) {
      if (released) return;
      released = true;
      _activeConnections.remove(connectionKey);
      if (boundSessionId != null) {
        store.markDisconnected(boundSessionId!);
      }
      _safeClose(closeConnection, code);
    }

    late final StreamSubscription<dynamic> sub;
    sub = stream.listen(
      (message) {
        if (message is! String) {
          _safeClose(closeConnection, WebSocketStatus.unsupportedData);
          return;
        }
        if (utf8.encode(message).length > config.maxMessageBytes) {
          _safeClose(closeConnection, WebSocketStatus.messageTooBig);
          return;
        }
        try {
          final decoded = jsonDecode(message);
          if (decoded is! Map) {
            throw const FormatException('Envelope must be a JSON object.');
          }
          final envelope = LevitEventEnvelope(
            Map<String, dynamic>.from(decoded),
          );
          final incomingSessionId = envelope.data['sessionId'];
          final resolvedId =
              (incomingSessionId is String && incomingSessionId.isNotEmpty)
                  ? incomingSessionId
                  : (boundSessionId ??= 'session-${++_fallbackSessionCounter}');
          boundSessionId = resolvedId;
          store.applyEnvelope(resolvedId, envelope, appId: appId);

          final seq = envelope.data['seq'];
          if (seq is int) {
            _safeSend(send, closeConnection, jsonEncode({'ack': seq}));
          }
        } catch (_) {
          _safeClose(closeConnection, WebSocketStatus.policyViolation);
        }
      },
      onError: (_) {
        _subscriptions.remove(sub);
        release();
      },
      onDone: () {
        _subscriptions.remove(sub);
        release();
      },
      cancelOnError: false,
    );
    _subscriptions.add(sub);
  }

  static Future<void> _reject(
    HttpResponse response,
    int statusCode,
    String body,
  ) async {
    response.statusCode = statusCode;
    response.write(body);
    await response.close();
  }

  static void _safeSend(
    void Function(String) send,
    Future<void> Function([int? code]) closeConnection,
    String payload,
  ) {
    try {
      send(payload);
    } catch (_) {
      _safeClose(closeConnection);
    }
  }

  static void _safeClose(
    Future<void> Function([int? code]) closeConnection, [
    int? code,
  ]) {
    try {
      unawaited(closeConnection(code).catchError((_) {}));
    } catch (_) {
      // Ignore close failures on already-broken sockets.
    }
  }

  /// Closes the loopback HTTP listener and all active producer sockets.
  ///
  /// Idempotent: subsequent calls return immediately. Active producer
  /// connections are closed with `WebSocketStatus.goingAway` (`1001`) before
  /// cancelling subscriptions and closing the underlying `HttpServer`.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final closers = _activeConnections.values.toList();
    _activeConnections.clear();
    for (final closeConnection in closers) {
      _safeClose(closeConnection, WebSocketStatus.goingAway);
    }
    final subs = _subscriptions.toList();
    _subscriptions.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
    await _server.close(force: true);
  }
}
