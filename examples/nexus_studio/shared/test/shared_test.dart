import 'package:test/test.dart';
import 'package:nexus_studio_shared/shared.dart';

void main() {
  group('Vec2', () {
    test('arithmetic', () {
      const v1 = Vec2(10, 20);
      const v2 = Vec2(5, 5);

      final sum = v1 + v2;
      expect(sum.x, 15);
      expect(sum.y, 25);

      final diff = v1 - v2;
      expect(diff.x, 5);
      expect(diff.y, 15);
    });

    test('serialization', () {
      const v = Vec2(10.5, 20.5);
      final json = v.toJson();
      expect(json, {'x': 10.5, 'y': 20.5});

      final v2 = Vec2.fromJson(json);
      expect(v2.x, 10.5);
      expect(v2.y, 20.5);
    });

    test('toString', () {
      expect(const Vec2(1, 2).toString(), 'Vec2(1.0, 2.0)');
    });
  });

  group('Rect', () {
    test('properties', () {
      const r = Rect(0, 0, 100, 50);
      expect(r.left, 0);
      expect(r.width, 100);
    });

    test('toString', () {
      expect(const Rect(1, 2, 3, 4).toString(), 'Rect(1.0, 2.0, 3.0, 4.0)');
    });
  });

  group('NodeModel', () {
    test('serialization', () {
      final node = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(10, 10),
        sz: const Vec2(50, 50),
        col: 0xFF000000,
      );

      final json = node.toJson();
      expect(json['id'], 'n1');
      expect(json['position']['x'], 10.0);

      final node2 = NodeModel.fromJson(json);
      expect(node2.id, 'n1');
      expect(node2.position.value.x, 10.0);
      expect(node2.color.value, 0xFF000000);
    });
  });

  group('RemoteUser', () {
    test('serialization', () {
      final user = RemoteUser(
        id: 'u1',
        name: 'Bob',
        color: 0xFFFF0000,
        cursorPos: const Vec2(100, 100),
      );

      final json = user.toJson();
      expect(json['name'], 'Bob');

      final user2 = RemoteUser.fromJson(json);
      expect(user2.name, 'Bob');
      expect(user2.cursor.value.x, 100.0);
    });
  });

  group('NexusEngine', () {
    late NexusEngine engine;

    setUp(() {
      // Levit.reset is good practice even if not strictly needed here
      // assuming shared.dart doesn't have hidden global state
      engine = NexusEngine();
    });

    test('controller lifecycle can run', () {
      engine.onInit();
      engine.onClose();
    });

    test('add/remove node', () {
      expect(engine.nodes.length, 0);

      final node = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0,
      );

      engine.addNode(node);
      expect(engine.nodes.length, 1);

      engine.removeNode('n1');
      expect(engine.nodes.length, 0);
    });

    test('bulkMove', () {
      final node = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0,
      );
      engine.addNode(node);

      engine.bulkMove({'n1'}, const Vec2(10, 10));
      expect(node.position.value.x, 10);
      expect(node.position.value.y, 10);
    });

    test('bulkUpdate', () {
      final node = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0,
      );
      engine.addNode(node);

      engine.bulkUpdate({'n1': const Vec2(50, 50)});
      expect(node.position.value.x, 50);
      expect(node.position.value.y, 50);
    });

    test('bulkColor', () {
      final node = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0xFF000000,
      );
      engine.addNode(node);

      engine.bulkColor({'n1': 0xFFFFFFFF});
      expect(node.color.value, 0xFFFFFFFF);
    });

    test('calculateBounds', () {
      final n1 = NodeModel(
        id: 'n1',
        type: 'rect',
        pos: const Vec2(0, 0),
        sz: const Vec2(10, 10),
        col: 0,
      );
      final n2 = NodeModel(
        id: 'n2',
        type: 'rect',
        pos: const Vec2(20, 20),
        sz: const Vec2(10, 10),
        col: 0,
      );

      // Empty
      expect(NexusEngine.calculateBounds([]), isNull);

      // Single
      var bounds = NexusEngine.calculateBounds([n1]);
      expect(bounds!.left, 0);
      expect(bounds.top, 0);
      expect(bounds.width, 10);
      expect(bounds.height, 10);

      // Multiple
      bounds = NexusEngine.calculateBounds([n1, n2]);
      expect(bounds!.left, 0);
      expect(bounds.top, 0);
      expect(bounds.width, 30); // 0 to 30 (20+10)
      expect(bounds.height, 30);
    });
  });
}
