import 'package:levit_dart_core/levit_dart_core.dart';
import 'shared.dart';

/// Immutable domain data: history never retains reactive node instances.
final class NodeSnapshot {
  final String id;
  final String type;
  final Vec2 position;
  final Vec2 size;
  final int color;
  const NodeSnapshot({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    required this.color,
  });
  factory NodeSnapshot.capture(NodeModel node) => NodeSnapshot(
    id: node.id,
    type: node.type,
    position: node.position.value,
    size: node.size.value,
    color: node.color.value,
  );
  NodeModel materialize() =>
      NodeModel(id: id, type: type, pos: position, sz: size, col: color);
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'position': position.toJson(),
    'size': size.toJson(),
    'color': color,
  };
}

/// An application edit with explicit forward and inverse operations.
sealed class NexusCommand {
  const NexusCommand();
  bool get isEmpty => false;
  void apply(NexusEngine engine, {required bool forward});
  Map<String, dynamic> message({required bool forward});
}

final class CreateNodeCommand extends NexusCommand {
  final NodeSnapshot node;
  const CreateNodeCommand(this.node);
  @override
  void apply(NexusEngine engine, {required bool forward}) {
    if (forward) {
      if (!engine.nodes.any((existing) => existing.id == node.id)) {
        engine.addNode(node.materialize());
      }
    } else {
      engine.removeNode(node.id);
    }
  }

  @override
  Map<String, dynamic> message({required bool forward}) => forward
      ? {'type': 'node_create', 'node': node.toJson()}
      : {'type': 'node_delete', 'id': node.id};
}

final class MoveNodesCommand extends NexusCommand {
  final Map<String, Vec2> before;
  final Map<String, Vec2> after;
  MoveNodesCommand(Map<String, Vec2> before, Map<String, Vec2> after)
    : before = Map.unmodifiable(before),
      after = Map.unmodifiable(after) {
    if (before.length != after.length ||
        !before.keys.every(after.containsKey)) {
      throw ArgumentError(
        'A position command requires matching before/after node IDs.',
      );
    }
  }
  @override
  bool get isEmpty => before.keys.every((id) => before[id] == after[id]);
  @override
  void apply(NexusEngine engine, {required bool forward}) =>
      engine.bulkUpdate(forward ? after : before);
  @override
  Map<String, dynamic> message({required bool forward}) => {
    'type': 'bulk_update',
    'positions': (forward ? after : before).map(
      (id, position) => MapEntry(id, position.toJson()),
    ),
  };
}

final class ColorNodesCommand extends NexusCommand {
  final Map<String, int> before;
  final Map<String, int> after;
  ColorNodesCommand(Map<String, int> before, Map<String, int> after)
    : before = Map.unmodifiable(before),
      after = Map.unmodifiable(after) {
    if (before.length != after.length ||
        !before.keys.every(after.containsKey)) {
      throw ArgumentError(
        'A color command requires matching before/after node IDs.',
      );
    }
  }
  @override
  bool get isEmpty => before.keys.every((id) => before[id] == after[id]);
  @override
  void apply(NexusEngine engine, {required bool forward}) =>
      engine.bulkColor(forward ? after : before);
  @override
  Map<String, dynamic> message({required bool forward}) => {
    'type': 'bulk_color',
    'colors': forward ? after : before,
  };
}

/// Local command history, deliberately reset by authoritative document changes.
/// Presence is handled separately. Sending an inverse uses the normal protocol.
final class NexusCommandHistory extends LevitController {
  final NexusEngine engine;
  final void Function(Map<String, dynamic>) send;
  final List<NexusCommand> _undo = [];
  final List<NexusCommand> _redo = [];
  late final LxInt _revision = own(0.lx);
  static const capacity = 100;
  NexusCommandHistory(this.engine, {required this.send});
  bool get canUndo {
    _revision.value;
    return _undo.isNotEmpty;
  }

  bool get canRedo {
    _revision.value;
    return _redo.isNotEmpty;
  }

  int get length {
    _revision.value;
    return _undo.length;
  }

  List<NexusCommand> get commands => List.unmodifiable(_undo);

  /// Also commits the final frame of a drag. Previews are never recorded.
  void execute(NexusCommand command) {
    if (command.isEmpty) return;
    Lx.batch(() {
      command.apply(engine, forward: true);
      _undo.add(command);
      if (_undo.length > capacity) _undo.removeAt(0);
      _redo.clear();
      _revision.value++;
    });
    send(command.message(forward: true));
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final command = _undo.last;
    Lx.batch(() {
      command.apply(engine, forward: false);
      _undo.removeLast();
      _redo.add(command);
      _revision.value++;
    });
    send(command.message(forward: false));
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final command = _redo.last;
    Lx.batch(() {
      command.apply(engine, forward: true);
      _redo.removeLast();
      _undo.add(command);
      _revision.value++;
    });
    send(command.message(forward: true));
    return true;
  }

  /// Applies authoritative changes and clears local inverses in the same batch.
  /// Returns false for presence and unknown messages, preserving local history.
  bool receiveDocument(Map<String, dynamic> data) => Lx.batch(() {
    if (!applyNexusDocumentMessage(engine, data)) return false;
    clear();
    return true;
  });

  void clear() {
    if (_undo.isEmpty && _redo.isEmpty) return;
    Lx.batch(() {
      _undo.clear();
      _redo.clear();
      _revision.value++;
    });
  }
}

/// Applies recognized document messages atomically. Returns false for presence
/// and unknown packets. Creation/deletion are idempotent by stable node ID.
bool applyNexusDocumentMessage(NexusEngine engine, Map<String, dynamic> data) {
  switch (data['type']) {
    case 'snapshot':
      Lx.batch(
        () => engine.replaceNodes(
          (data['nodes'] as List).map(
            (node) => NodeModel.fromJson(Map<String, dynamic>.from(node)),
          ),
        ),
      );
    case 'bulk_move':
      engine.bulkMove(
        Set<String>.from(data['ids']),
        Vec2.fromJson(data['delta']),
      );
    case 'bulk_update':
      engine.bulkUpdate(
        (data['positions'] as Map<String, dynamic>).map(
          (id, value) => MapEntry(id, Vec2.fromJson(value)),
        ),
      );
    case 'bulk_color':
      engine.bulkColor(Map<String, int>.from(data['colors']));
    case 'node_create':
      final raw = Map<String, dynamic>.from(data['node']);
      if (!engine.nodes.any((node) => node.id == raw['id'])) {
        engine.addNode(NodeModel.fromJson(raw));
      }
    case 'node_delete':
      engine.removeNode(data['id'] as String);
    default:
      return false;
  }
  return true;
}
