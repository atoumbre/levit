import 'dart:convert';

import 'package:levit_dart/levit_dart.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';
import 'package:nexus_server/server_adapter.dart';

export 'server_adapter.dart';

/// Controller for the Nexus Studio server.
///
/// Manages websocket connections, synchronizes state between clients, and
/// maintains the authoritative [NexusEngine] state.
///
/// This controller demonstrates how Levit can be used in a backend environment,
/// sharing the same reactive logic and models as the Flutter client.
class ServerController extends LevitController {
  /// The shared game engine instance.
  final engine = Levit.find<NexusEngine>();

  /// Reactive tracking of connected clients.
  final clients = <WebSocketChannel>{}.lx;

  /// Computed property for logging/monitoring.
  late final clientCount = (() => clients.length).lx;

  /// Whether to auto-start the server on initialization.
  final bool autoStart;

  final ServerAdapter _adapter;

  /// Creates a server controller.
  ServerController({
    this.autoStart = true,
    ServerAdapter? adapter,
  }) : _adapter = adapter ?? ServerAdapter();

  @override
  void onInit() {
    super.onInit();
    if (autoStart) startServer();

    // Log when client count changes
    // This demonstrates reactive side-effects on the server
    autoDispose(
      clientCount.stream.listen((count) {
        print('📊 Connected Clients: $count');
      }),
    );

    // Demonstrate Isomorphic Reactivity:
    // The server reacts to changes in the shared engine model just like the client!
    autoDispose(
      engine.nodes.stream.listen((_) {
        print('📦 Server Node Count: ${engine.nodes.length}');
      }),
    );
  }

  /// Starts the WebSocket server.
  Future<void> startServer() async {
    seedData();

    final handler = webSocketHandler(handleConnection);

    final server = await _adapter.serve(handler, '0.0.0.0', 8080);
    print('--- Nexus Studio Server ---');
    print('Status: ONLINE');
    print('Address: ws://${server.address.host}:${server.port}');
    print('Pillars: Isomorphic, High Performance, Real-time');
  }

  /// Seeds initial data if the engine is empty.
  void seedData() {
    // Seed initial data if empty
    if (engine.nodes.isEmpty) {
      engine.addNode(NodeModel(
        id: '1',
        type: 'rect',
        pos: const Vec2(100, 100),
        sz: const Vec2(100, 100),
        col: 0xFF6366F1,
      ));
      engine.addNode(NodeModel(
        id: '2',
        type: 'circle',
        pos: const Vec2(300, 200),
        sz: const Vec2(80, 80),
        col: 0xFFEC4899,
      ));
    }
  }

  /// Handles a new WebSocket connection.
  void handleConnection(WebSocketChannel webSocket, String? protocol) {
    print('New collaborator joined');
    clients.add(webSocket);

    // Send snapshot
    final snapshot = {
      'type': 'snapshot',
      'nodes': engine.nodes.map((n) => n.toJson()).toList(),
    };
    webSocket.sink.add(jsonEncode(snapshot));

    // Listen for messages
    webSocket.stream.listen(
      (message) {
        processMessage(webSocket, message);
      },
      onDone: () {
        print('Collaborator left');
        clients.remove(webSocket);
      },
      onError: (e) {
        print('Error handling client: $e');
        clients.remove(webSocket);
      },
    );
  }

  /// Processes an incoming message from a client.
  ///
  /// *   [client]: The client sending the message.
  /// *   [message]: The JSON message string.
  void processMessage(WebSocketChannel client, dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final String type = data['type'];
      final senderId = client.hashCode.toString();

      // We attach the sender ID so clients know who sent the update
      final packetMap = Map<String, dynamic>.from(data);
      packetMap['senderId'] = senderId;
      final packet = jsonEncode(packetMap);

      // 1. Update Server State (Source of Truth)
      // We use Levity's reactivity to keep the server model in sync
      if (type == 'bulk_move') {
        final ids = Set<String>.from(data['ids']);
        final delta = Vec2.fromJson(data['delta']);
        engine.bulkMove(ids, delta);
      } else if (type == 'bulk_update') {
        final Map<String, dynamic> positionsRaw = data['positions'];
        final positions = positionsRaw.map(
          (k, v) => MapEntry(k, Vec2.fromJson(v)),
        );
        engine.bulkUpdate(positions);
      } else if (type == 'bulk_color') {
        final Map<String, dynamic> colorsRaw = data['colors'];
        final colors = colorsRaw.map((k, v) => MapEntry(k, v as int));
        engine.bulkColor(colors);
      } else if (type == 'node_create') {
        engine.addNode(NodeModel.fromJson(data['node']));
      } else if (type == 'presence_update') {
        // Presence is ephemeral, we don't store it in the engine permanently
        // but we relay it.
      }

      // 2. Broadcast to others
      // Using LxSet iteration
      for (final otherClient in clients) {
        if (otherClient != client) {
          otherClient.sink.add(packet);
        }
      }
    } catch (e) {
      print('Invalid message: $e');
    }
  }
}
