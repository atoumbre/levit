import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:nexus_studio_server/server.dart';
import 'package:nexus_studio_shared/shared.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class Client {
  final WebSocketChannel channel;
  final engine = NexusEngine();
  late final history = NexusCommandHistory(
    engine,
    send: (message) => channel.sink.add(jsonEncode(message)),
  );
  late final StreamSubscription<dynamic> subscription;
  final List<Completer<void>> _waiters = [];
  int received = 0;
  Client(this.channel) {
    subscription = channel.stream.listen((message) {
      history.receiveDocument(
        Map<String, dynamic>.from(jsonDecode(message as String)),
      );
      received++;
      for (final waiter in _waiters.toList()) {
        if (!waiter.isCompleted) waiter.complete();
      }
      _waiters.clear();
    });
  }
  Future<void> waitForMessages(int count) async {
    while (received < count) {
      final next = Completer<void>();
      _waiters.add(next);
      await next.future.timeout(const Duration(seconds: 5));
    }
  }

  Future<void> close() async {
    await channel.sink.close();
    await subscription.cancel();
    await history.onClose();
    await engine.onClose();
  }
}

void main() {
  test(
    'two websocket clients converge after undoing creation and movement',
    () async {
      final scope = LevitScope.root('server');
      final engine = scope.put(() => NexusEngine());
      final server = scope.run(
        () => scope.put(() => ServerController(autoStart: false)),
      );
      final http = await shelf_io.serve(
        webSocketHandler(server.handleConnection),
        InternetAddress.loopbackIPv4,
        0,
      );
      final uri = Uri.parse('ws://127.0.0.1:${http.port}');
      final a = Client(WebSocketChannel.connect(uri));
      final b = Client(WebSocketChannel.connect(uri));
      addTearDown(() async {
        await a.close();
        await b.close();
        await http.close(force: true);
        await scope.dispose();
      });
      await Future.wait([a.waitForMessages(1), b.waitForMessages(1)]);
      const created = NodeSnapshot(
        id: 'created',
        type: 'rect',
        position: Vec2(1, 2),
        size: Vec2(10, 10),
        color: 1,
      );
      a.history.execute(const CreateNodeCommand(created));
      await b.waitForMessages(2);
      expect(engine.nodes.single.id, 'created');
      expect(b.engine.nodes.single.toJson(), a.engine.nodes.single.toJson());
      a.history.undo();
      await b.waitForMessages(3);
      expect(engine.nodes, isEmpty);
      expect(a.engine.nodes, isEmpty);
      expect(b.engine.nodes, isEmpty);
      a.history.redo();
      await b.waitForMessages(4);
      a.history.execute(
        MoveNodesCommand(
          {'created': const Vec2(1, 2)},
          {'created': const Vec2(50, 60)},
        ),
      );
      await b.waitForMessages(5);
      a.history.undo();
      await b.waitForMessages(6);
      expect(engine.nodes.single.position.value, const Vec2(1, 2));
      expect(b.engine.nodes.single.toJson(), a.engine.nodes.single.toJson());
      a.history.redo();
      await b.waitForMessages(7);
      expect(engine.nodes.single.position.value, const Vec2(50, 60));
      expect(b.engine.nodes.single.toJson(), a.engine.nodes.single.toJson());
      expect(b.history.canUndo, isFalse);
    },
  );
}
