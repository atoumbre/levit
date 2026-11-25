import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:nexus_studio_shared/shared.dart';
import 'package:test/test.dart';

NodeSnapshot node(String id) => NodeSnapshot(
  id: id,
  type: 'rect',
  position: const Vec2(0, 0),
  size: const Vec2(10, 10),
  color: 1,
);

void main() {
  late NexusEngine engine;
  late NexusCommandHistory history;
  late List<Map<String, dynamic>> sent;
  setUp(() {
    engine = NexusEngine();
    sent = [];
    history = NexusCommandHistory(engine, send: sent.add);
  });
  tearDown(() async {
    await history.onClose();
    await engine.onClose();
  });

  test(
    'creation undo restores the collection, redo materializes fresh state',
    () {
      history.execute(CreateNodeCommand(node('a')));
      final original = engine.nodes.single;
      expect(history.undo(), isTrue);
      expect(engine.nodes, isEmpty);
      expect(sent.last, {'type': 'node_delete', 'id': 'a'});
      expect(history.redo(), isTrue);
      expect(engine.nodes.single.toJson(), node('a').toJson());
      expect(engine.nodes.single, isNot(same(original)));
    },
  );

  test('bulk movement undo and redo publish atomic observer values', () async {
    history.execute(CreateNodeCommand(node('a')));
    history.execute(CreateNodeCommand(node('b')));
    history.clear();
    final sum = LxComputed(
      () => engine.nodes.fold(0.0, (sum, node) => sum + node.position.value.x),
    );
    final seen = <double>[];
    sum.addListener(() => seen.add(sum.value));
    final before = {
      for (final node in engine.nodes) node.id: node.position.value,
    };
    final after = {'a': const Vec2(1, 1), 'b': const Vec2(2, 2)};
    final command = MoveNodesCommand(before, after);
    before.clear();
    after.clear(); // Snapshots are not caller-owned maps.
    history.execute(command);
    history.undo();
    history.redo();
    expect(seen, [3, 0, 3]);
    expect(sent.last['positions'], {
      'a': {'x': 1.0, 'y': 1.0},
      'b': {'x': 2.0, 'y': 2.0},
    });
    await sum.close();
  });

  test(
    'drag previews do not record history; committing stores one inverse',
    () {
      engine.addNode(node('a').materialize());
      final before = {'a': engine.nodes.single.position.value};
      for (var i = 1; i <= 10; i++) {
        engine.bulkUpdate({'a': Vec2(i.toDouble(), 0)});
      }
      expect(history.length, 0);
      history.execute(
        MoveNodesCommand(before, {'a': engine.nodes.single.position.value}),
      );
      expect(history.length, 1);
      history.undo();
      expect(engine.nodes.single.position.value, const Vec2(0, 0));
    },
  );

  test(
    'color inverses, new edits clear redo, unchanged edits create nothing',
    () {
      history.execute(CreateNodeCommand(node('a')));
      history.execute(ColorNodesCommand({'a': 1}, {'a': 2}));
      history.undo();
      expect(engine.nodes.single.color.value, 1);
      history.redo();
      expect(engine.nodes.single.color.value, 2);
      history.undo();
      history.execute(ColorNodesCommand({'a': 1}, {'a': 3}));
      expect(history.canRedo, isFalse);
      final length = history.length;
      history.execute(ColorNodesCommand({'a': 3}, {'a': 3}));
      expect(history.length, length);
    },
  );

  test(
    'history bounds, remote reset, presence preservation and idempotent deletion',
    () {
      for (var i = 0; i < 105; i++) {
        history.execute(CreateNodeCommand(node('$i')));
      }
      expect(history.length, 100);
      expect(history.receiveDocument({'type': 'presence_update'}), isFalse);
      expect(history.length, 100);
      history.receiveDocument({'type': 'node_delete', 'id': '0'});
      expect(history.canUndo, isFalse);
      history.receiveDocument({'type': 'node_delete', 'id': '0'});
      expect(engine.nodes.length, 104);
      history.execute(CreateNodeCommand(node('local')));
      history.receiveDocument({
        'type': 'snapshot',
        'nodes': [node('server').toJson()],
      });
      expect(history.length, 0);
      expect(engine.nodes.single.id, 'server');
    },
  );
}
