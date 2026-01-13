import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:levit_dart/levit_dart.dart';
import 'package:nexus_server/server.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:async/async.dart';

// Simple fake WebSocketChannel since Mockito requires strict types or code gen
class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController _controller = StreamController();
  final StreamController _sinkController = StreamController();

  @override
  Stream get stream => _controller.stream;

  @override
  WebSocketSink get sink => _FakeSink(_sinkController);

  void simulateIncoming(dynamic message) {
    _controller.add(message);
  }

  void simulateError(dynamic error) {
    _controller.addError(error);
  }

  Future<void> simulateClose() => _controller.close();

  // To inspect sent messages
  Stream get sentMessages => _sinkController.stream;

  @override
  void pipe(StreamChannel<dynamic> other) {
    // Basic impl if needed, or ignore
  }

  @override
  StreamChannel<S> transform<S>(
      StreamChannelTransformer<S, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformStream(
      StreamTransformer<dynamic, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformSink(
      StreamSinkTransformer<dynamic, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeStream(Stream Function(Stream) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeSink(StreamSink Function(StreamSink) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<S> cast<S>() {
    throw UnimplementedError();
  }

  @override
  String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  Future start() async {} // Not used by server probably

  @override
  Future get ready => Future.value();
}

class _FakeSink implements WebSocketSink {
  final StreamController _controller;
  _FakeSink(this._controller);

  @override
  void add(data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _controller.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) => _controller.close();

  @override
  Future get done => _controller.done;
}

void main() {
  late ServerController server;
  late NexusEngine engine;

  setUp(() {
    Levit.reset(force: true);
    engine = Levit.put(() => NexusEngine(), permanent: true);
    // Auto-start false to prevent binding port
    server = Levit.put(() => ServerController(autoStart: false));
  });

  test('seedData seeds data if empty', () {
    expect(engine.nodes.length, 0);
    server.seedData();
    expect(engine.nodes.length, 2);

    // Calling again should not duplicate
    server.seedData();
    expect(engine.nodes.length, 2);
  });

  test('handleConnection adds client and sends snapshot', () async {
    final socket = FakeWebSocketChannel();
    engine.addNode(NodeModel(
        id: '1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0));

    server.handleConnection(socket, 'protocol');

    expect(server.clients.length, 1);

    final snapshot = await socket.sentMessages.first;
    final data = jsonDecode(snapshot);
    expect(data['type'], 'snapshot');
    expect((data['nodes'] as List).length, 1);
  });

  test('socket stream listener triggers processMessage', () async {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, 'protocol');

    // Simulate incoming message
    final msg = jsonEncode({
      'type': 'node_create',
      'node': NodeModel(
              id: 'stream_test',
              type: 'rect',
              pos: const Vec2(100, 100),
              sz: const Vec2(100, 100),
              col: 0xFF00FF00)
          .toJson()
    });

    client.simulateIncoming(msg);

    // Wait for async processing
    await Future.delayed(Duration.zero);

    // Verify side effect
    expect(engine.nodes.any((n) => n.id == 'stream_test'), true);
  });

  test('processMessage handles updates and broadcasts', () async {
    final client1 = FakeWebSocketChannel();
    final client2 = FakeWebSocketChannel();

    server.handleConnection(client1, null);
    server.handleConnection(client2, null);

    // Client 1 moves a node
    // First ensure node exists
    engine.addNode(NodeModel(
        id: 'node1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0));

    final moveMsg = jsonEncode({
      'type': 'bulk_move',
      'ids': ['node1'],
      'delta': {'x': 100.0, 'y': 100.0}
    });

    // Simulate incoming message
    server.processMessage(client1, moveMsg);

    // Check engine update
    expect(engine.nodes.first.position.value.x, 100.0);

    // Check broadcast to client 2
    // Skip the initial snapshot sent on connection
    final broadcastMsg = await client2.sentMessages.skip(1).first;
    final broadcastData = jsonDecode(broadcastMsg);
    expect(broadcastData['type'], 'bulk_move');
    expect(broadcastData['senderId'], isNotNull); // attached helper
  });

  test('processMessage handles create node', () {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);

    final createMsg = jsonEncode({
      'type': 'node_create',
      'node': NodeModel(
              id: 'new',
              type: 'circle',
              pos: const Vec2(10, 10),
              sz: const Vec2(10, 10),
              col: 0)
          .toJson()
    });

    server.processMessage(client, createMsg);
    expect(engine.nodes.any((n) => n.id == 'new'), true);
  });

  test('processMessage handles bulk_update', () {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);
    engine.addNode(NodeModel(
        id: 'node1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0));

    final msg = jsonEncode({
      'type': 'bulk_update',
      'positions': {
        'node1': {'x': 50.0, 'y': 50.0}
      }
    });
    server.processMessage(client, msg);
    expect(engine.nodes.first.position.value.x, 50.0);
  });

  test('processMessage handles bulk_color', () {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);
    engine.addNode(NodeModel(
        id: 'node1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0));

    final msg = jsonEncode({
      'type': 'bulk_color',
      'colors': {'node1': 0xFF00FF00}
    });
    server.processMessage(client, msg);
    expect(engine.nodes.first.color.value, 0xFF00FF00);
  });

  test('processMessage handles presence_update', () {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);

    final msg = jsonEncode({
      'type': 'presence_update',
      'cursor': {'x': 10.0, 'y': 10.0}
    });
    // Just ensure no crash, presence is ephemeral on server (just broadcast)
    server.processMessage(client, msg);
  });

  test('processMessage handles invalid json gracefully', () {
    final client = FakeWebSocketChannel();
    expect(
        () => server.processMessage(client, 'invalid json'), returnsNormally);
    // Prints 'Invalid message: ...'
  });

  test('handle connection sends snapshot and listens', () {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, 'fake_protocol');

    expect(server.clients.contains(client), true);

    // Initial snapshot sent
    expect(client.sentMessages, emitsThrough(contains('snapshot')));
  });

  // ... existing tests ...

  test('startServer seeding and startup', () async {
    // Re-create controller with adapter
    final adapter = FakeServerAdapter();
    server = Levit.put(
        () => ServerController(autoStart: false, adapter: adapter),
        permanent: true);

    // Force empty logic verification
    server.engine.nodes.clear();

    await server.startServer();

    expect(server.engine.nodes.length, 2); // Seeded
    expect(adapter.serveCalled, true);
  });

  test('client disconnect removes from list', () async {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);
    expect(server.clients.contains(client), true);

    await client.simulateClose();
    // Wait for stream listener onDone
    await Future.delayed(Duration.zero);
    expect(server.clients.contains(client), false);
  });

  test('client error removes from list', () async {
    final client = FakeWebSocketChannel();
    server.handleConnection(client, null);
    expect(server.clients.contains(client), true);

    client.simulateError('Oops');
    await Future.delayed(Duration.zero);
    expect(server.clients.contains(client), false);
  });
}

class FakeServerAdapter implements ServerAdapter {
  bool serveCalled = false;

  @override
  Future<io.HttpServer> serve(dynamic handler, Object address, int port) async {
    serveCalled = true;
    return MockHttpServer();
  }
}

class MockHttpServer implements io.HttpServer {
  @override
  io.InternetAddress get address => io.InternetAddress.loopbackIPv4;

  @override
  int get port => 8080;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
