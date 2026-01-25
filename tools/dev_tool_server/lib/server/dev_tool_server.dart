import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:shelf/shelf.dart'
    as shelf_io; // Use alias for consistency or just import Request
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/app_session.dart';

/// The main server that listens for incoming connections from Levit apps.
/// The main server that listens for incoming connections from Levit apps.
class DevToolController extends LevitController {
  HttpServer? _server;
  final int port;

  /// Active sessions keyed by sessionId.
  final sessions = <String, AppSession>{}.lx;

  DevToolController({this.port = 9200});

  /// Starts the server.
  Future<void> start() async {
    // We wrap the simple webSocketHandler to capture request details (appId)
    FutureOr<shelf_io.Response> handler(shelf_io.Request request) {
      final appId = request.url.queryParameters['appId'];

      final connectionHandler = webSocketHandler((
        WebSocketChannel webSocket,
        String? protocol,
      ) {
        _onConnection(webSocket, appId: appId);
      });

      return connectionHandler(request);
    }

    // We bind to ANY IPv4 to allow connections from flexible environments/emulators
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print(
      'DevTool Server running on ws://${_server!.address.host}:${_server!.port}',
    );
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    print('DevTool Server stopped');
  }

  void _onConnection(WebSocketChannel webSocket, {String? appId}) {
    // We don't have sessionId yet, it comes in the first message usually.
    // Or maybe we should expect it in query params too?
    // For now we wait for the first message to identify the session.
    // But we can store the appId temporarily associated with this channel if needed.

    // Actually, capturing the variable 'appId' in the closure for listen
    // allows passing it to _handleMessage or _linkSession.

    webSocket.stream.listen(
      (message) {
        _handleMessage(message, webSocket, appId: appId);
      },
      onError: (error) {
        print('WS Error: $error');
        _handleDisconnect(webSocket);
      },
      onDone: () {
        print('WS Connection closed');
        _handleDisconnect(webSocket);
      },
    );
  }

  // We keep a map of WebSocket -> SessionId to handle disconnects
  final Map<WebSocketChannel, String> _activeSockets = {};

  void _handleMessage(
    dynamic message,
    WebSocketChannel webSocket, {
    String? appId,
  }) {
    if (message is! String) return;

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;

      final sessionId = json['sessionId'] as String?;
      if (sessionId == null) return;

      final session = sessions.putIfAbsent(sessionId, () {
        // Create new session
        final newSession = AppSession(sessionId: sessionId, appId: appId);
        return newSession;
      });

      // Ensure we track this socket
      if (!_activeSockets.containsKey(webSocket)) {
        _activeSockets[webSocket] = sessionId;

        // Update session connection status
        if (!session.isConnected.value) {
          session.isConnected.value = true;
        }
      }

      final event = _parseEvent(json);
      if (event != null) {
        session.handleEvent(event, message);
      }
    } catch (e, st) {
      print('Error handling message: $e\n$st');
    }
  }

  void _handleDisconnect(WebSocketChannel webSocket) {
    final sessionId = _activeSockets.remove(webSocket);
    if (sessionId != null) {
      final session = sessions[sessionId];
      if (session != null) {
        session.isConnected.value = false;
      }
    }
  }

  MonitorEvent? _parseEvent(Map<String, dynamic> json) {
    // This is a simplified manual parser. In production this should be in `levit_monitor`.
    final type = json['type'] as String?;
    final sessionId = json['sessionId'] as String;

    if (type == null) {
      return null; // Base MonitorEvent usually doesn't have type unless subclass
    }

    // Reactive Events
    if (type.startsWith('reactive_') ||
        type == 'state_change' ||
        type == 'batch' ||
        type == 'graph_change' ||
        type == 'listener_add' ||
        type == 'listener_remove') {
      // We need to reconstruct the Reactive object which might be partial
      // But StateSnapshot doesn't need the FULL original object, just the ID/Name.

      final reactiveId = int.tryParse(json['reactiveId']?.toString() ?? '');
      if (reactiveId == null && type != 'batch') return null;

      final reactive = LxReactiveImpl(
        id: reactiveId ?? -1,
        name: json['name'] ?? '?',
        ownerId: json['ownerId'],
      );

      if (type == 'reactive_init') {
        // We can't easily reconstruct the exact event without changing core to support fromJson
        // But we can approximate for the StateSnapshot.
        return ReactiveInitEvent(sessionId: sessionId, reactive: reactive);
      } else if (type == 'reactive_dispose') {
        return ReactiveDisposeEvent(sessionId: sessionId, reactive: reactive);
      } else if (type == 'state_change') {
        return ReactiveChangeEvent(
          sessionId: sessionId,
          reactive: reactive,
          change: LevitReactiveChange(
            timestamp: DateTime.now(),
            oldValue: json['oldValue'],
            newValue: json['newValue'],
            restore: (_) {}, // Dummy restore
            valueType: String,
          ),
        );
      }
      // ... implement other cases
    }

    // Dependency Events
    if (type.startsWith('di_')) {
      final scopeId = json['scopeId'] as int;
      final key = json['key'] as String;
      final scopeName = json['scopeName'] as String;

      // Mock info
      final info = LevitDependency(
        isLazy: json['isLazy'] == true,
        isFactory: json['isFactory'] == true,
      );

      if (type == 'di_register') {
        return DependencyRegisterEvent(
          sessionId: sessionId,
          scopeId: scopeId,
          scopeName: scopeName,
          key: key,
          info: info,
          source: json['source'] ?? '?',
        );
      } else if (type == 'di_delete') {
        return DependencyDeleteEvent(
          sessionId: sessionId,
          scopeId: scopeId,
          scopeName: scopeName,
          key: key,
          info: info,
          source: json['source'] ?? '?',
        );
      }
      // ... others
    }

    return null;
  }
}

// Temporary mocks to make the parser work since we don't have full access to internal constructors or fromJson in levit_monitor yet
class LxReactiveImpl implements LxReactive<dynamic> {
  @override
  final int id;
  @override
  final String name;
  @override
  final String? ownerId;
  @override
  dynamic value;

  LxReactiveImpl({required this.id, required this.name, this.ownerId});

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
