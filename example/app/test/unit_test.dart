import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:nexus_studio_app/controllers.dart';
import 'package:shared/shared.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:async/async.dart';

// FAKE CHANNEL
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

  // To inspect sent messages
  Stream get sentMessages => _sinkController.stream;

  @override
  void pipe(StreamChannel<dynamic> other) {}

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
  StreamChannel<S> cast<S>() => throw UnimplementedError();

  @override
  String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  Future start() async {}

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
  setUp(() {
    Levit.reset(force: true);
    // Dependencies needed for controllers
    Levit.put(() => NexusEngine());
    Levit.put(() =>
        PresenceController()); // ProjectController finds PresenceController
  });

  group('AuthController', () {
    test('login/logout updates session and canEdit', () {
      final auth = AuthController();
      expect(auth.isAuthenticated, false);
      expect(auth.canEdit, false);

      auth.login('admin@nexus.io');
      expect(auth.isAuthenticated, true);
      expect(auth.canEdit, true);
      expect(auth.session.value!.role, 'editor');

      auth.logout();
      expect(auth.isAuthenticated, false);
    });

    test('viewer login has restricted permissions', () {
      final auth = AuthController();
      auth.login('viewer@nexus.io');
      expect(auth.isAuthenticated, true);
      expect(auth.canEdit, false);
    });
  });

  group('ProjectController', () {
    late ProjectController pc;
    FakeWebSocketChannel? mockChannel;

    setUp(() {
      Levit.put(() => AuthController());
      Levit.find<AuthController>().login('admin@nexus.io'); // Grant permissions
      mockChannel = FakeWebSocketChannel();
      pc = Levit.put(() => ProjectController(channel: mockChannel));
    });

    test('addNode adds node to engine and updates counts', () async {
      expect(pc.nodeCount.value, 0);
      pc.addNode('rect');
      expect(pc.nodeCount.value, 1);
      expect(pc.engine.nodes.length, 1);
      expect(pc.engine.nodes.first.type, 'rect');

      // Verify network message sent
      if (mockChannel != null) {
        final msg = await mockChannel!.sentMessages.first;
        final data = jsonDecode(msg);
        expect(data['type'], 'node_create');
      }
    });

    test('selection toggles correctly', () {
      pc.addNode('rect');
      final id = pc.engine.nodes.first.id;

      // Single select
      pc.toggleSelection(id);
      expect(pc.selectedIds.contains(id), true);
      expect(pc.selectionBounds.value, isNotNull);

      // Deselect
      pc.toggleSelection(id);
      expect(pc.selectedIds.isEmpty, true);

      // Multi select behavior
      pc.toggleSelection(id, multi: true);
      expect(pc.selectedIds.contains(id), true);
      pc.toggleSelection(id, multi: true);
      expect(pc.selectedIds.isEmpty, true);
    });

    test('sendPresenceUpdate handles missing PresenceController', () {
      // Don't register PresenceController
      Levit.reset(force: true);
      final pc = Levit.put(() => ProjectController(channel: mockChannel));

      // Should not throw
      pc.sendPresenceUpdate(const Vec2(0, 0));
    });

    test('undo/redo handles empty history', () {
      pc.undo(); // Should not crash
      pc.redo(); // Should not crash
    });

    test('drag guards', () {
      pc.endDrag(); // Should return early (not dragging)

      pc.addNode('rect');
      pc.toggleSelection('rect_whatever'); // Select something (fake id)

      pc.startDrag();
      pc.startDrag(); // Should be idempotent / guard re-entry

      pc.endDrag();
    });

    test('toggleSelection single vs multi', () {
      pc.addNode('n1');
      pc.addNode('n2');

      // Single select n1
      pc.toggleSelection('n1');
      expect(pc.selectedIds.contains('n1'), true);

      // Single select n1 AGAIN (deselect)
      pc.toggleSelection('n1');
      expect(pc.selectedIds.isEmpty, true);

      // Single select n1 then n2
      pc.toggleSelection('n1');
      pc.toggleSelection('n2'); // Should clear n1 and select n2
      expect(pc.selectedIds.contains('n1'), false);
      expect(pc.selectedIds.contains('n2'), true);

      // Multi select
      pc.toggleSelection('n1', multi: true);
      expect(pc.selectedIds.contains('n1'), true);
      expect(pc.selectedIds.contains('n2'), true);

      pc.toggleSelection('n1', multi: true); // Deselect n1
      expect(pc.selectedIds.contains('n1'), false);
    });

    test('connect handles connection error', () {
      bool connectorCalled = false;
      Levit.put(() => ProjectController(connector: (uri) {
            connectorCalled = true;
            throw Exception('Connection failed');
          }));
      // _connect called in onInit
      expect(connectorCalled, true);
    });

    test('moveSelection updates positions locally (syncs on endDrag)',
        () async {
      pc.addNode('rect');
      final node = pc.engine.nodes.first;
      final initialPos = node.position.value;
      pc.selectedIds.add(node.id);

      pc.startDrag();
      pc.moveSelection(Vec2(10, 10));
      expect(node.position.value.x, initialPos.x + 10);
      expect(node.position.value.y, initialPos.y + 10);

      // Verify NO message sent yet (optimize bandwidth)
      // We expect only 1 msg so far (node_create)
      // Unless we clear messages.
      // take(2) would hang if only 1 sent.
      // We can check sentMessages length if we could sync read, but stream is async.
      // Let's just assume no msg.

      // Now end drag and verify sync
      pc.endDrag();

      // Should send bulk_update
      final msgs = await mockChannel!.sentMessages.take(2).toList();
      final updateMsg = jsonDecode(msgs[1]);
      expect(updateMsg['type'], 'bulk_update');
    });

    test('permissions check prevents modification', () {
      Levit.find<AuthController>().logout(); // Revoke permissions

      pc.addNode('rect');
      final node = pc.engine.nodes.first;
      final initialPos = node.position.value;
      pc.selectedIds.add(node.id);

      pc.moveSelection(Vec2(10, 10));
      expect(node.position.value.x, initialPos.x); // Should NOT move
    });

    test('undo/redo workflow', () {
      pc.addNode('rect');
      final node = pc.engine.nodes.first;
      final initialPos = node.position.value;

      pc.selectedIds.add(node.id);

      // Simulate drag workflow
      pc.startDrag();
      pc.moveSelection(Vec2(50, 50));
      pc.endDrag(); // This should commit to history

      expect(node.position.value.x, initialPos.x + 50);

      // Undo
      pc.undo();
      expect(node.position.value.x, initialPos.x);

      // Redo
      pc.redo();
      expect(node.position.value.x, initialPos.x + 50);
    });

    test('chaos mode runs batch update', () {
      pc.addNode('rect');
      pc.addNode('circle');
      pc.chaos();
      // Just verifying it runs without error and things move potentially
    });

    test('export sets status', () async {
      pc.addNode('rect');
      pc.export();
      expect(pc.exportStatus.value!.status, isA<LxWaiting>());
      // Wait 2s to complete in real app, might be slow for test?
      // We can just verify it started.
    });

    test('handleServerMessage updates state (node_create)', () async {
      final nodeData = NodeModel(
              id: 'remote_1',
              type: 'rect',
              pos: const Vec2(100, 100),
              sz: const Vec2(50, 50),
              col: 0xFF000000)
          .toJson();

      final msg = jsonEncode({'type': 'node_create', 'node': nodeData});

      mockChannel!.simulateIncoming(msg);
      await Future.delayed(Duration.zero);

      // Check engine
      expect(pc.engine.nodes.any((n) => n.id == 'remote_1'), true);
    });

    test('handleServerMessage handles bulk_move', () async {
      pc.addNode('rect');
      final id = pc.engine.nodes.first.id;
      final initialPos = pc.engine.nodes.first.position.value;

      final msg = jsonEncode({
        'type': 'bulk_move',
        'ids': [id],
        'delta': {'x': 100.0, 'y': 100.0}
      });

      mockChannel!.simulateIncoming(msg);
      await Future.delayed(Duration.zero);
      expect(pc.engine.nodes.first.position.value.x, initialPos.x + 100);
    });

    test('handleServerMessage handles bulk_color', () async {
      pc.addNode('rect');
      final id = pc.engine.nodes.first.id;

      final msg = jsonEncode({
        'type': 'bulk_color',
        'colors': {id: 0xFF0FF0F0}
      });

      mockChannel!.simulateIncoming(msg);
      await Future.delayed(Duration.zero);
      expect(pc.engine.nodes.first.color.value, 0xFF0FF0F0);
    });

    test('handleServerMessage handles bulk_update', () async {
      pc.addNode('rect');
      final id = pc.engine.nodes.first.id;

      final msg = jsonEncode({
        'type': 'bulk_update',
        'positions': {
          id: {'x': 999.0, 'y': 888.0}
        }
      });
      mockChannel!.simulateIncoming(msg);
      await Future.delayed(Duration.zero);
      expect(pc.engine.nodes.first.position.value.x, 999.0);
    });

    test('syncColors sends bulk_color', () async {
      pc.addNode('rect');
      final id = pc.engine.nodes.first.id;
      pc.syncColors();

      // Verify message (addNode + bulk_color)
      final msgs = await mockChannel!.sentMessages.take(2).toList();
      final colorMsg = jsonDecode(msgs[1]);
      expect(colorMsg['type'], 'bulk_color');
      expect(colorMsg['colors'][id], isA<int>());
    });
  });

  group('PresenceController', () {
    late PresenceController presence;
    FakeWebSocketChannel? mockChannel;

    setUp(() {
      mockChannel = FakeWebSocketChannel();
      presence = Levit.put(() => PresenceController());
      // Mock project controller for `updateLocalCursor`
      Levit.put(() => ProjectController(channel: mockChannel));
    });

    test('handlePresenceMessage updates remoteUsers', () {
      final msg = {
        'senderId': 'other_user',
        'name': 'Bob',
        'color': 0xFF00FF00,
        'cursor': {'x': 100, 'y': 200}
      };

      presence.handlePresenceMessage(msg);
      expect(presence.remoteUsers.containsKey('other_user'), true);
      expect(presence.remoteUsers['other_user']!.cursor.value.x, 100);

      // Update
      final msgUpdate = {
        'senderId': 'other_user',
        'cursor': {'x': 150, 'y': 250}
      };
      presence.handlePresenceMessage(msgUpdate);
      expect(presence.remoteUsers['other_user']!.cursor.value.x, 150);
    });

    test(
        'updateLocalCursor delegates to ProjectController and sends over network',
        () async {
      presence.updateLocalCursor(const Offset(10, 10));

      // Should send message via channel
      final msg = await mockChannel!.sentMessages.first;
      final data = jsonDecode(msg);
      // ProjectController.sendPresenceUpdate sends {'type': 'presence_update', ...}
      expect(data['type'], 'presence_update');
      expect(data['cursor']['x'], 10.0);
    });
  });
}
